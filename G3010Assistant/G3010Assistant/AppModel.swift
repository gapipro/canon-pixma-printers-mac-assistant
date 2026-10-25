import AppKit
import Combine
import SwiftUI

/// Wires discovery, the selected printer, the Keychain password, and maintenance actions.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var printers: [PrinterDevice] = []
    @Published var selectedPrinter: PrinterDevice?
    @Published var isSelectingPrinter = false
    @Published var isPromptingPassword = false
    @Published var passwordError: String?
    @Published var activeAction: AssistantAction?
    @Published var isShowingStatus = false
    @Published private(set) var printerStatus: PrinterStatus?
    @Published private(set) var statusError: String?
    @Published private(set) var isLoadingStatus = false
    @Published private(set) var isResolvingCredentials = false
    /// Factory serial from SNMP (also the usual default Remote UI password).
    @Published private(set) var selectedPrinterSerial: String?

    /// Last selected printer host. Restored when discovery or a manual add lists this host again.
    @AppStorage("lastPrinterHost") private var lastPrinterHost = ""

    private let browser: any PrinterBrowsing
    private let liveBrowser: PrinterBrowser?
    private var printerSubscription: AnyCancellable?
    private var remote: RemoteUISession?
    private var maintenance: MaintenanceService?
    private var sessionHost: String?
    private let cups = CupsCommandClient()

    init() {
        let browser = PrinterBrowser()
        self.browser = browser
        self.liveBrowser = browser
        bind(browser)
    }

    init(previewPrinters: [PrinterDevice]) {
        let browser = PreviewPrinterBrowser(printers: previewPrinters)
        self.browser = browser
        self.liveBrowser = nil
        bind(browser)
        if selectedPrinter == nil {
            selectedPrinter = previewPrinters.first
        }
    }

    func startBrowsing() {
        browser.start()
    }

    func addManualPrinter(ip: String) {
        let host = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        if let liveBrowser {
            liveBrowser.addManualPrinter(ip: host)
        } else if !printers.contains(where: { $0.host == host }) {
            printers.append(PrinterBrowser.manualDevice(host: host))
        }
        select(PrinterBrowser.manualDevice(host: host))
    }

    func select(_ printer: PrinterDevice) {
        lastPrinterHost = printer.host
        selectedPrinter = printer
        printerStatus = nil
        statusError = nil
        selectedPrinterSerial = nil
        isSelectingPrinter = false
        if sessionHost != printer.host {
            remote = nil
            maintenance = nil
            sessionHost = nil
        }
        connect(host: printer.host)
        Task {
            await refreshSelectedSerial()
            await ensureCredentials(promptIfNeeded: true)
        }
    }

    func savePassword(_ password: String) {
        guard let printer = selectedPrinter, !password.isEmpty else { return }
        KeychainStore.savePassword(password, forHost: printer.host)
        passwordError = nil
        connect(host: printer.host)
        isPromptingPassword = false
    }

    func begin(_ action: AssistantAction) {
        guard let printer = selectedPrinter else {
            isSelectingPrinter = true
            return
        }
        if maintenance == nil || sessionHost != printer.host {
            connect(host: printer.host)
        }
        if canRunWithoutPassword(action, options: ActionOptions()) {
            passwordError = nil
            activeAction = action
            return
        }
        Task {
            let ready = await ensureCredentials(promptIfNeeded: true)
            guard ready else { return }
            passwordError = nil
            activeAction = action
        }
    }

    /// Presents the password sheet after the action sheet has closed.
    func promptForRejectedPasswordIfNeeded() {
        guard passwordError != nil, let host = selectedPrinter?.host else { return }
        guard KeychainStore.password(forHost: host) == nil else { return }
        isPromptingPassword = true
    }

    func perform(_ action: AssistantAction, options: ActionOptions = ActionOptions()) async throws {
        guard let printer = selectedPrinter else {
            throw AppError.unreachable("no printer selected")
        }
        if remote == nil || maintenance == nil || sessionHost != printer.host {
            connect(host: printer.host)
        }
        guard let remote, let maintenance else {
            throw AppError.unreachable(printer.host)
        }

        if canRunWithoutPassword(action, options: options) {
            try await maintenance.run(action, options: options)
            return
        }

        let password = try await requirePassword(for: printer)
        do {
            try await remote.login(password: password)
            try await maintenance.run(action, options: options)
        } catch let error as AppError {
            if error == .authFailed {
                KeychainStore.deletePassword(forHost: printer.host)
                passwordError = error.localizedDescription
            }
            throw error
        }
    }

    func openRemoteUI() {
        guard let host = selectedPrinter?.host else { return }
        if remote == nil || sessionHost != host {
            connect(host: host)
        }
        guard let remote else { return }
        Task {
            let url = await remote.remoteUIHomeURL()
            NSWorkspace.shared.open(url)
        }
    }

    func refreshStatus() async {
        guard let printer = selectedPrinter else {
            printerStatus = nil
            statusError = "Select a printer first."
            return
        }
        if remote == nil || maintenance == nil || sessionHost != printer.host {
            connect(host: printer.host)
        }
        guard let remote, let maintenance else { return }

        isLoadingStatus = true
        statusError = nil
        defer { isLoadingStatus = false }

        let ready = await ensureCredentials(promptIfNeeded: true)
        guard ready, let password = KeychainStore.password(forHost: printer.host) else {
            printerStatus = nil
            statusError = AppError.authFailed.localizedDescription
            return
        }
        do {
            try await remote.login(password: password)
            printerStatus = try await maintenance.status()
        } catch let error as AppError {
            if error == .authFailed {
                KeychainStore.deletePassword(forHost: printer.host)
                passwordError = error.localizedDescription
            }
            printerStatus = nil
            statusError = error.localizedDescription
        } catch {
            printerStatus = nil
            statusError = error.localizedDescription
        }
    }

    /// Keychain → SNMP serial (factory default password) → optional prompt.
    @discardableResult
    func ensureCredentials(promptIfNeeded: Bool) async -> Bool {
        guard let printer = selectedPrinter else { return false }
        if KeychainStore.password(forHost: printer.host) != nil {
            if maintenance == nil || sessionHost != printer.host {
                connect(host: printer.host)
            }
            return true
        }
        isResolvingCredentials = true
        defer { isResolvingCredentials = false }
        do {
            let serial = try await SerialNumberClient.fetchSerial(host: printer.host)
            if selectedPrinter?.host == printer.host {
                selectedPrinterSerial = serial
            }
            if remote == nil || sessionHost != printer.host {
                connect(host: printer.host)
            }
            guard let remote else { return false }
            try await remote.login(password: serial)
            KeychainStore.savePassword(serial, forHost: printer.host)
            passwordError = nil
            return true
        } catch {
            if promptIfNeeded {
                passwordError = nil
                isPromptingPassword = true
            }
            return false
        }
    }

    private func canRunWithoutPassword(_ action: AssistantAction, options: ActionOptions) -> Bool {
        // CHMP PowerOff does not use Remote UI auth.
        if action == .powerOff { return true }
        guard CupsCommandClient.supports(action), cups.availableQueue() != nil else { return false }
        if action == .headAlignment, options.headAlignment != .automatic { return false }
        return true
    }

    private func refreshSelectedSerial() async {
        guard let host = selectedPrinter?.host else {
            selectedPrinterSerial = nil
            return
        }
        do {
            let serial = try await SerialNumberClient.fetchSerial(host: host)
            guard selectedPrinter?.host == host else { return }
            selectedPrinterSerial = serial
        } catch {
            guard selectedPrinter?.host == host else { return }
            // Keep nil; top bar just omits the serial line.
        }
    }

    private func requirePassword(for printer: PrinterDevice) async throws -> String {
        if let existing = KeychainStore.password(forHost: printer.host) {
            return existing
        }
        let ready = await ensureCredentials(promptIfNeeded: true)
        guard ready, let password = KeychainStore.password(forHost: printer.host) else {
            passwordError = AppError.authFailed.localizedDescription
            throw AppError.authFailed
        }
        return password
    }

    private func connect(host: String) {
        let remote = RemoteUISession(host: host)
        let chmp = CHMPClient(host: host)
        self.remote = remote
        self.maintenance = MaintenanceService(chmp: chmp, remote: remote, cups: cups)
        self.sessionHost = host
    }

    private func bind<B: PrinterBrowsing & ObservableObject>(_ browser: B) {
        applyPrinters(browser.printers)
        printerSubscription = browser.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.applyPrinters(browser.printers)
            }
        }
    }

    /// `objectWillChange` runs before `@Published` updates, so callers read `browser.printers` on the next turn.
    private func applyPrinters(_ printers: [PrinterDevice]) {
        self.printers = printers
        restoreLastPrinterIfNeeded()
    }

    /// Selects the stored host once it shows up. A later resolve of that same host updates the name without reconnecting.
    private func restoreLastPrinterIfNeeded() {
        let host = lastPrinterHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let match = printers.first(where: { $0.host == host }) else { return }
        if let selected = selectedPrinter {
            if selected.host == host, selected != match {
                selectedPrinter = match
            }
            return
        }
        select(match)
    }
}
