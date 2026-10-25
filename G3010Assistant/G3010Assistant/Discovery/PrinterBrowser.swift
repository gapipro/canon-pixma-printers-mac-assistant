import Combine
import Darwin
import Foundation
import Network
import os

/// Browse and list printers. Previews can use `PreviewPrinterBrowser` instead of live Bonjour.
@MainActor
protocol PrinterBrowsing: AnyObject {
    var printers: [PrinterDevice] { get }
    func start()
    func stop()
}

/// Browses `_ipp._tcp` on `local.` and keeps services whose name or TXT mentions Canon or G3010.
///
/// Bonjour browse results carry the service name and TXT (`ty`, `usb_MDL`), not an address.
/// A short TCP connection to the advertised IPP endpoint is how Network.framework resolves that service to a host.
/// A failed resolve retries about 8 seconds later from the last browse results, even when that set does not change.
@MainActor
final class PrinterBrowser: ObservableObject, PrinterBrowsing {
    nonisolated static let serviceType = "_ipp._tcp"
    nonisolated static let serviceDomain = "local."
    private static let resolveRetryDelay: TimeInterval = 8

    @Published private(set) var printers: [PrinterDevice] = []

    private let log = Logger(subsystem: "local.g3010.assistant", category: "discovery")
    private var browser: NWBrowser?
    /// Bumped on `start` and `stop` so browse updates, resolves, and scheduled retries from an older session are ignored.
    private var generation = 0
    private var manualByHost: [String: PrinterDevice] = [:]
    private var resolvedByKey: [String: PrinterDevice] = [:]
    private var resolvers: [String: EndpointResolver] = [:]
    /// Identifies the in-flight resolve or the retry scheduled for it. Replaced to drop stale callbacks.
    private var attemptTokens: [String: UUID] = [:]
    private var retryAfter: [String: Date] = [:]
    private var retryTasks: [String: Task<Void, Never>] = [:]
    private var lastResults: Set<NWBrowser.Result> = []

    func start() {
        guard browser == nil else { return }
        generation += 1
        let generation = generation

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: Self.serviceType, domain: Self.serviceDomain),
            using: params
        )
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.log.info("IPP browse state: \(String(describing: state), privacy: .public)")
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.apply(results: results, generation: generation)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        generation += 1
        browser?.cancel()
        browser = nil
        let pending = resolvers
        resolvers.removeAll()
        resolvedByKey.removeAll()
        attemptTokens.removeAll()
        retryAfter.removeAll()
        lastResults = []
        let retries = retryTasks
        retryTasks.removeAll()
        for task in retries.values {
            task.cancel()
        }
        for resolver in pending.values {
            resolver.cancel()
        }
        publish()
    }

    /// Manual LAN entry when Bonjour does not list the printer.
    func addManualPrinter(ip: String) {
        let host = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        manualByHost[host] = Self.manualDevice(host: host)
        publish()
    }

    nonisolated static func manualDevice(host: String) -> PrinterDevice {
        PrinterDevice(name: "Manual", host: host, model: "G3010")
    }

    /// True when the service name or any TXT value contains Canon or G3010.
    nonisolated static func isCanonOrG3010(name: String, txt: [String: String]) -> Bool {
        let fields = [name] + txt.values
        return fields.contains { field in
            field.range(of: "Canon", options: .caseInsensitive) != nil
                || field.range(of: "G3010", options: .caseInsensitive) != nil
        }
    }

    nonisolated static func device(name: String, host: String, txt: [String: String]) -> PrinterDevice {
        let model = txtValue(txt, "ty") ?? txtValue(txt, "usb_MDL") ?? "G3010"
        return PrinterDevice(name: name, host: host, model: model)
    }

    /// Address suitable for `http://{host}/`. Unresolved Bonjour service endpoints return nil.
    nonisolated static func hostString(from endpoint: NWEndpoint?) -> String? {
        guard let endpoint else { return nil }
        switch endpoint {
        case .hostPort(let host, _):
            return hostString(from: host)
        default:
            return nil
        }
    }

    private func apply(results: Set<NWBrowser.Result>, generation: Int) {
        guard self.generation == generation else { return }
        lastResults = results

        var matching: [String: Match] = [:]
        for result in results {
            guard case .service(let name, let type, let domain, _) = result.endpoint else { continue }
            let txt = Self.txtDictionary(from: result)
            guard Self.isCanonOrG3010(name: name, txt: txt) else { continue }
            let key = Self.serviceKey(name: name, type: type, domain: domain)
            if matching[key] == nil {
                matching[key] = Match(name: name, txt: txt, endpoint: result.endpoint)
            }
        }

        for key in resolvedByKey.keys where matching[key] == nil {
            resolvedByKey[key] = nil
        }
        let tracked = Set(resolvers.keys).union(retryAfter.keys).union(retryTasks.keys)
        for key in tracked where matching[key] == nil {
            invalidateAttempt(key)
        }

        let now = Date()
        for (key, match) in matching {
            if let existing = resolvedByKey[key] {
                resolvedByKey[key] = Self.device(name: match.name, host: existing.host, txt: match.txt)
                continue
            }
            if resolvers[key] != nil { continue }
            if let until = retryAfter[key], until > now { continue }

            let token = UUID()
            attemptTokens[key] = token
            let resolver = EndpointResolver(endpoint: match.endpoint) { [weak self] host in
                Task { @MainActor in
                    self?.didResolve(
                        key: key,
                        name: match.name,
                        txt: match.txt,
                        host: host,
                        token: token,
                        generation: generation
                    )
                }
            }
            resolvers[key] = resolver
            resolver.start()
        }
        publish()
    }

    private func didResolve(
        key: String,
        name: String,
        txt: [String: String],
        host: String?,
        token: UUID,
        generation: Int
    ) {
        guard self.generation == generation, attemptTokens[key] == token else { return }
        resolvers[key] = nil
        if let host, !host.isEmpty {
            invalidateAttempt(key)
            resolvedByKey[key] = Self.device(name: name, host: host, txt: txt)
            log.info("Resolved \(name, privacy: .public) at \(host, privacy: .public)")
        } else {
            retryAfter[key] = Date().addingTimeInterval(Self.resolveRetryDelay)
            log.info("Could not resolve \(name, privacy: .public); will retry")
            scheduleRetry(key: key, name: name, token: token, generation: generation)
        }
        publish()
    }

    /// Browse results often stay stable after a failed resolve, so `browseResultsChangedHandler` will not call `apply` again.
    private func scheduleRetry(key: String, name: String, token: UUID, generation: Int) {
        retryTasks[key]?.cancel()
        let delay = UInt64(Self.resolveRetryDelay * 1_000_000_000)
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled else { return }
            guard self.generation == generation, self.attemptTokens[key] == token else { return }
            self.retryTasks[key] = nil
            self.attemptTokens[key] = nil
            self.retryAfter[key] = nil
            self.log.info("Retrying resolve for \(name, privacy: .public)")
            self.apply(results: self.lastResults, generation: generation)
        }
        retryTasks[key] = task
    }

    private func invalidateAttempt(_ key: String) {
        attemptTokens[key] = nil
        retryAfter[key] = nil
        retryTasks[key]?.cancel()
        retryTasks[key] = nil
        resolvers[key]?.cancel()
        resolvers[key] = nil
    }

    private nonisolated static func serviceKey(name: String, type: String, domain: String) -> String {
        "\(name)\u{0}\(type)\u{0}\(domain)"
    }

    private func publish() {
        var byHost = manualByHost
        for device in resolvedByKey.values {
            byHost[device.host] = device
        }
        printers = byHost.values.sorted { lhs, rhs in
            let byName = lhs.name.localizedStandardCompare(rhs.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return lhs.host < rhs.host
        }
    }

    private nonisolated static func txtDictionary(from result: NWBrowser.Result) -> [String: String] {
        if case .bonjour(let record) = result.metadata {
            return record.dictionary
        }
        return result.endpoint.txtRecord?.dictionary ?? [:]
    }

    private nonisolated static func txtValue(_ txt: [String: String], _ key: String) -> String? {
        if let value = txt[key], !value.isEmpty { return value }
        guard let pair = txt.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) else {
            return nil
        }
        return pair.value.isEmpty ? nil : pair.value
    }

    private nonisolated static func hostString(from host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let address):
            return numericAddress(address.rawValue, family: AF_INET)
        case .ipv6(let address):
            guard let text = numericAddress(address.rawValue, family: AF_INET6) else { return nil }
            return "[\(text)]"
        case .name(let name, _):
            var trimmed = name
            if trimmed.hasSuffix(".") { trimmed.removeLast() }
            return trimmed.isEmpty ? nil : trimmed
        @unknown default:
            return nil
        }
    }

    private nonisolated static func numericAddress(_ data: Data, family: Int32) -> String? {
        let capacity = Int(family == AF_INET ? INET_ADDRSTRLEN : INET6_ADDRSTRLEN)
        var buffer = [CChar](repeating: 0, count: capacity)
        let copied = data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return false }
            return inet_ntop(family, base, &buffer, socklen_t(capacity)) != nil
        }
        guard copied else { return nil }
        let text = String(cString: buffer)
        return text.isEmpty ? nil : text
    }
}

/// Fixed printer list for SwiftUI previews.
@MainActor
final class PreviewPrinterBrowser: ObservableObject, PrinterBrowsing {
    @Published private(set) var printers: [PrinterDevice]

    init(printers: [PrinterDevice]? = nil) {
        self.printers = printers ?? Self.samplePrinters
    }

    func start() {}

    func stop() {}

    nonisolated static let samplePrinters = [
        PrinterDevice(name: "Canon G3010 series", host: "192.168.1.50", model: "G3010")
    ]
}

private struct Match: Sendable {
    var name: String
    var txt: [String: String]
    var endpoint: NWEndpoint
}

/// Opens the Bonjour service only long enough to read the resolved remote host, then cancels.
private final class EndpointResolver: @unchecked Sendable {
    private let connection: NWConnection
    private let lock = NSLock()
    private var completed = false
    private let onHost: @Sendable (String?) -> Void

    init(endpoint: NWEndpoint, onHost: @escaping @Sendable (String?) -> Void) {
        self.onHost = onHost
        connection = NWConnection(to: endpoint, using: Self.resolveParameters())
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        connection.start(queue: .global(qos: .utility))
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finish(nil)
        }
    }

    func cancel() {
        finish(nil)
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            finish(PrinterBrowser.hostString(from: connection.currentPath?.remoteEndpoint))
        case .failed, .cancelled:
            finish(nil)
        default:
            break
        }
    }

    private static func resolveParameters() -> NWParameters {
        let params = NWParameters.tcp
        params.preferNoProxies = true
        params.includePeerToPeer = true
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        return params
    }

    private func finish(_ host: String?) {
        lock.lock()
        if completed {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        connection.cancel()
        onHost(host)
    }
}
