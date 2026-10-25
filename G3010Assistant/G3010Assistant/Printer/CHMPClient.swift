import Foundation

actor CHMPClient {
    private let host: String
    private let session: URLSession
    private let statusURL: URL

    init(host: String, session: URLSession = CHMPClient.makeSession()) {
        self.host = host
        self.session = session
        self.statusURL = URL(string: "http://\(host)/canon/ij/command2/port1")!
    }

    /// Short timeouts: live G3010 CHMP GetStatus often never responds; callers fall back to Remote UI.
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    func fetchPrintStatus() async throws -> PrinterStatus {
        try await postThenGetStatus(body: CHMPXML.getStatus(serviceType: "print"))
    }

    func fetchDeviceStatus() async throws -> PrinterStatus {
        try await postThenGetStatus(body: CHMPXML.getStatus(serviceType: "device"))
    }

    /// Soft power-off via CHMP (Windows `Send_PowerOff`).
    ///
    /// Live G3010: POST to `command2/port1` is accepted, then the TCP session is reset as the
    /// device powers down. Waiting for a GET `PowerOffResponse` times out even when off succeeded.
    func powerOff() async throws {
        var post = URLRequest(url: statusURL)
        post.httpMethod = "POST"
        post.setValue("1.4.0", forHTTPHeaderField: "X-CHMP-Version")
        post.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        post.setValue("Close", forHTTPHeaderField: "Connection")
        post.httpBody = CHMPXML.powerOff()
        do {
            let (data, response) = try await session.data(for: post)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                if !data.isEmpty {
                    try? CHMPXML.parsePowerOffResponse(data)
                }
                return
            }
            throw AppError.unreachable(host)
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            // Connection drop / timeout after the POST is the usual success path on this firmware.
            switch error.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
                return
            default:
                throw AppError.unreachable(host)
            }
        } catch {
            throw AppError.unreachable(host)
        }
    }

    private func postThenGetStatus(body: Data) async throws -> PrinterStatus {
        let data = try await postThenGetData(body: body)
        return try CHMPXML.parseGetStatusResponse(data)
    }

    private func postThenGetData(body: Data) async throws -> Data {
        var post = URLRequest(url: statusURL)
        post.httpMethod = "POST"
        post.setValue("1.4.0", forHTTPHeaderField: "X-CHMP-Version")
        post.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        post.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        post.httpBody = body
        let (_, postResp) = try await session.data(for: post)
        guard let http = postResp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.unreachable(host)
        }
        var get = URLRequest(url: statusURL)
        get.httpMethod = "GET"
        get.setValue("1.4.0", forHTTPHeaderField: "X-CHMP-Version")
        get.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        let (data, getResp) = try await session.data(for: get)
        guard let httpGet = getResp as? HTTPURLResponse else { throw AppError.unreachable(host) }
        guard (200..<300).contains(httpGet.statusCode) else {
            throw AppError.http(httpGet.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
