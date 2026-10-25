import Foundation

/// Password-less maintenance via the local CUPS/Gutenprint `#CUPS-COMMAND` path
/// (same mechanism as 9M2PJU’s G-series Linux tool).
struct CupsCommandClient {
    var listQueues: () -> [String] = CupsCommandClient.readQueues
    var runLP: (String, URL) throws -> Void = CupsCommandClient.runLPProcess

    static func supports(_ action: AssistantAction) -> Bool {
        payload(for: action) != nil
    }

    static func payload(for action: AssistantAction) -> String? {
        switch action {
        case .cleaning:
            return "#CUPS-COMMAND\nClean all\n"
        case .nozzleCheck:
            return "#CUPS-COMMAND\nPrintSelfTestPage\n"
        case .headAlignment:
            return "#CUPS-COMMAND\ncom.canon.autoalignment\n"
        default:
            return nil
        }
    }

    static func pickQueue(from queues: [String]) -> String? {
        let preferred = queues.first { $0.localizedCaseInsensitiveContains("G3010") }
            ?? queues.first {
                $0.localizedCaseInsensitiveContains("Canon")
                    && ($0.localizedCaseInsensitiveContains("G30")
                        || $0.localizedCaseInsensitiveContains("G20")
                        || $0.localizedCaseInsensitiveContains("G10")
                        || $0.localizedCaseInsensitiveContains("G40"))
            }
        return preferred
    }

    func availableQueue() -> String? {
        Self.pickQueue(from: listQueues())
    }

    func send(_ action: AssistantAction) async throws {
        guard let payload = Self.payload(for: action) else {
            throw AppError.endpointMissing(action)
        }
        guard let queue = availableQueue() else {
            throw AppError.cupsQueueMissing
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("g3010-\(action.rawValue)-\(UUID().uuidString).utl")
        try Data(payload.utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        try runLP(queue, url)
    }

    private static func readQueues() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-a"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let name = line.split(separator: " ", maxSplits: 1).first.map(String.init)
            return name.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    private static func runLPProcess(queue: String, file: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lp")
        process.arguments = ["-d", queue, file.path]
        let err = Pipe()
        process.standardError = err
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AppError.cupsFailed(message.isEmpty ? "lp exit \(process.terminationStatus)" : message)
        }
    }
}
