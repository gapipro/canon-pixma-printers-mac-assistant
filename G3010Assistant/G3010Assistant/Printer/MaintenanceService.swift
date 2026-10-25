import Foundation

actor MaintenanceService {
    private let chmp: CHMPClient
    private let remote: RemoteUISession

    init(chmp: CHMPClient, remote: RemoteUISession) {
        self.chmp = chmp
        self.remote = remote
    }

    func ensureIdle() async throws {
        let status = try await chmp.fetchPrintStatus()
        if !status.isIdle { throw AppError.busy(status.detail) }
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
