import Foundation

actor MaintenanceService {
    private let chmp: CHMPClient
    private let remote: RemoteUISession
    private let cups: CupsCommandClient

    init(
        chmp: CHMPClient,
        remote: RemoteUISession,
        cups: CupsCommandClient = CupsCommandClient()
    ) {
        self.chmp = chmp
        self.remote = remote
        self.cups = cups
    }

    /// CHMP GetStatus often returns 409 or times out on this G3010. A parsed busy status still blocks.
    /// When CHMP fails, Remote UI `BST_STATE` decides. If that read fails too, the printer is unreachable
    /// and the action does not run.
    func ensureIdle() async throws {
        do {
            let status = try await chmp.fetchPrintStatus()
            if !status.isIdle { throw AppError.busy(status.detail) }
        } catch let error as AppError {
            if case .busy = error { throw error }
            try await requireRemoteIdle()
        } catch {
            try await requireRemoteIdle()
        }
    }

    private func requireRemoteIdle() async throws {
        let host = await remote.host
        do {
            if try await remote.fetchPrinterBusy() {
                throw AppError.busy("BST_STATE != 0")
            }
        } catch let error as AppError {
            if case .busy = error { throw error }
            throw AppError.unreachable(host)
        } catch {
            throw AppError.unreachable(host)
        }
    }

    /// Prefer local CUPS `#CUPS-COMMAND` (password-less) for mapped actions; otherwise Remote UI.
    func run(_ action: AssistantAction, options: ActionOptions = ActionOptions()) async throws {
        if shouldPreferCups(action, options: options), cups.availableQueue() != nil {
            do {
                try await cups.send(action)
                return
            } catch {
                // Sandbox or missing filter — fall through to Remote UI.
            }
        }
        if actionRequiresIdle(action) {
            try await ensureIdle()
        }
        guard let endpoint = EndpointMap.endpoint(for: action, options: options) else {
            throw AppError.endpointMissing(action)
        }
        switch endpoint.kind {
        case .chmp:
            guard action == .powerOff else {
                throw AppError.endpointMissing(action)
            }
            try await chmp.powerOff()
        case .remoteUIForm:
            try await remote.perform(endpoint)
        }
    }

    private func shouldPreferCups(_ action: AssistantAction, options: ActionOptions) -> Bool {
        guard CupsCommandClient.supports(action) else { return false }
        if action == .headAlignment, options.headAlignment != .automatic {
            return false
        }
        return true
    }

    private func actionRequiresIdle(_ action: AssistantAction) -> Bool {
        switch action {
        case .quietSettings, .autoPower, .customSettings, .inkNotificationSettings, .powerOff:
            return false
        default:
            return true
        }
    }

    /// Prefer CHMP GetStatus; on this G3010 it often conflicts or hangs, so fall back to Remote UI `BST_STATE`.
    func status() async throws -> PrinterStatus {
        do {
            return try await chmp.fetchPrintStatus()
        } catch {
            return try await remotePrinterStatus()
        }
    }

    private func remotePrinterStatus() async throws -> PrinterStatus {
        let host = await remote.host
        do {
            let busy = try await remote.fetchPrinterBusy()
            return PrinterStatus(isIdle: !busy, detail: busy ? "busy" : "idle", model: nil)
        } catch let error as AppError {
            if case .authFailed = error { throw error }
            throw AppError.unreachable(host)
        } catch {
            throw AppError.unreachable(host)
        }
    }
}
