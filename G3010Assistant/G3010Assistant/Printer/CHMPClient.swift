import Foundation

actor CHMPClient {
    private let host: String
    private let session: URLSession
    private let statusURL: URL

    init(host: String, session: URLSession = .shared) {
        self.host = host
        self.session = session
        self.statusURL = URL(string: "http://\(host)/canon/ij/command2/port1")!
    }

    func fetchPrintStatus() async throws -> PrinterStatus {
        try await postThenGet(body: CHMPXML.getStatus(serviceType: "print"))
    }

    func fetchDeviceStatus() async throws -> PrinterStatus {
        try await postThenGet(body: CHMPXML.getStatus(serviceType: "device"))
    }

    private func postThenGet(body: Data) async throws -> PrinterStatus {
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
        return try CHMPXML.parseGetStatusResponse(data)
    }
}
