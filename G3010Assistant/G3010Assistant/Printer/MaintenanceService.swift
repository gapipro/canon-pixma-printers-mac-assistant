import Foundation

actor MaintenanceService {
    private let chmp: CHMPClient
    private let remote: RemoteUISession

    init(chmp: CHMPClient, remote: RemoteUISession) {
        self.chmp = chmp
        self.remote = remote
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

    func run(_ action: AssistantAction) async throws {
        try await ensureIdle()
        guard let endpoint = EndpointMap.endpoint(for: action) else {
            throw AppError.endpointMissing(action)
        }
        switch endpoint.kind {
        case .chmp:
            // future: CHMPClient.perform(endpoint)
            throw AppError.endpointMissing(action)
        case .remoteUIForm:
            try await remote.perform(endpoint)
        }
    }

    func status() async throws -> PrinterStatus {
        try await chmp.fetchPrintStatus()
    }
}
