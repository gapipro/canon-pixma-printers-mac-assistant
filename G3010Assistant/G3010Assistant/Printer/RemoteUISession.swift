import CryptoKit
import Foundation

actor RemoteUISession {
    /// Captured Remote UI login POST. Password is SHA-256 hex in `NAMAE`, never plaintext.
    static let loginPath = "/rui/sendpw.cgi"

    /// Form field that carries the SHA-256 hex digest of the admin password.
    static let passwordField = "NAMAE"

    let host: String
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage
    private var loggedIn = false
    private var sbid: String?

    init(host: String, session: URLSession) {
        self.host = host
        self.session = session
        let storage = session.configuration.httpCookieStorage ?? HTTPCookieStorage()
        // `URLSession(configuration:)` can hand back a jar still on the default
        // `.onlyFromMainDocumentURL` policy, which drops Set-Cookie from data tasks.
        storage.cookieAcceptPolicy = .always
        self.cookieStorage = storage
    }

    convenience init(host: String) {
        self.init(host: host, session: URLSession(configuration: Self.makeSessionConfiguration()))
    }

    /// Ephemeral configuration whose built-in cookie jar is private to the session.
    /// A `HTTPCookieStorage()` created separately does not retain cookies; keep the one `ephemeral` already owns.
    /// Callers that inject a `URLSession` (tests) should start from this.
    static func makeSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage?.cookieAcceptPolicy = .always
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return config
    }

    func login(password: String) async throws {
        let page = URLRequest(url: url(path: "/rui/login_manager.html"))
        let (_, pageResponse) = try await load(page)
        try acceptLogin(pageResponse)

        var request = URLRequest(url: url(path: Self.loginPath))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let digest = Self.sha256Hex(password)
        request.httpBody = Data("\(Self.passwordField)=\(digest)&IDTYPE=2".utf8)

        let (data, response) = try await load(request)
        try acceptLogin(response)
        let html = String(data: data, encoding: .utf8) ?? ""
        guard let sbid = Self.extractSBID(from: html) else { throw AppError.authFailed }

        var index = URLRequest(url: url(path: "/rui/index.html"))
        index.httpMethod = "POST"
        index.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        index.httpBody = Data("SBID=\(Self.formEscape(sbid))".utf8)
        let (_, indexResponse) = try await load(index)
        try acceptLogin(indexResponse)

        self.sbid = sbid
        loggedIn = true
    }

    /// Printer status from Remote UI. `true` when `BST_STATE` is present and not `0`.
    /// Requires a logged-in session so the body can include `SBID`.
    func fetchPrinterBusy() async throws -> Bool {
        guard loggedIn, let sbid else { throw AppError.authFailed }
        var request = URLRequest(url: url(path: "/rui/prninfo_data.cgi"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("GETINFO=0&SBID=\(Self.formEscape(sbid))".utf8)
        let (data, response) = try await load(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.unreachable(host) }
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.http(http.statusCode, text)
        }
        guard let state = Self.bstState(in: text) else {
            throw AppError.parse("response missing BST_STATE")
        }
        return state != "0"
    }

    func perform(_ endpoint: ActionEndpoint) async throws {
        guard loggedIn || endpoint.kind == .chmp else { throw AppError.authFailed }
        let url = url(path: endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        let body = requestBody(for: endpoint)
        if !body.isEmpty {
            request.httpBody = Data(body.utf8)
            let contentType = endpoint.kind == .chmp
                ? "application/octet-stream"
                : "application/x-www-form-urlencoded"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await load(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.unreachable(host) }
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.http(http.statusCode, text)
        }
        guard Self.isSuccessful(body: text, marker: endpoint.successContains) else {
            let expected = endpoint.successContains == "RW_OK" ? "RW_OK or RW_POLLING" : endpoint.successContains
            throw AppError.parse("response missing \(expected)")
        }
    }

    func remoteUIHomeURL() -> URL {
        URL(string: "http://\(host)/")!
    }

    /// Lowercase hex SHA-256 of the password's UTF-8 bytes (CryptoJS.SHA256).
    static func sha256Hex(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// First `<BST_STATE>…</BST_STATE>` value, or nil when the tag is absent.
    static func bstState(in xml: String) -> String? {
        let open = "<BST_STATE>"
        let close = "</BST_STATE>"
        guard let start = xml.range(of: open),
              let end = xml.range(of: close, range: start.upperBound..<xml.endIndex) else {
            return nil
        }
        let value = xml[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func extractSBID(from html: String) -> String? {
        let patterns = [
            #"(?i)name\s*=\s*["']SBID["'][^>]*value\s*=\s*["']([^"']+)["']"#,
            #"(?i)value\s*=\s*["']([^"']+)["'][^>]*name\s*=\s*["']SBID["']"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  let valueRange = Range(match.range(at: 1), in: html) else { continue }
            let value = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private func acceptLogin(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw AppError.authFailed }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AppError.authFailed
        }
        guard (200..<400).contains(http.statusCode) else {
            throw AppError.authFailed
        }
    }

    private func requestBody(for endpoint: ActionEndpoint) -> String {
        guard endpoint.kind == .remoteUIForm, let sbid else { return endpoint.bodyTemplate }
        let pair = "SBID=\(Self.formEscape(sbid))"
        if endpoint.bodyTemplate.isEmpty { return pair }
        return "\(endpoint.bodyTemplate)&\(pair)"
    }

    /// Job-kick pages return `RW_OK` or `RW_POLLING`. `RW_NG` is a failure even if the marker is `RW_OK`.
    private static func isSuccessful(body: String, marker: String) -> Bool {
        if marker == "RW_OK" {
            if body.contains("RW_NG") { return false }
            return body.contains("RW_OK") || body.contains("RW_POLLING")
        }
        return body.contains(marker)
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let redirect = CookieRedirectDelegate(storage: cookieStorage, host: host)
        let request = applyingCookies(to: request)
        do {
            let (data, response) = try await session.data(for: request, delegate: redirect)
            if let http = response as? HTTPURLResponse {
                redirect.store(http)
            }
            return (data, response)
        } catch {
            throw AppError.unreachable(host)
        }
    }

    /// URLProtocol mocks do not receive the Cookie header URLSession would add for a real HTTP stack.
    /// Copy the jar onto the request so login cookies are sent for both.
    private func applyingCookies(to request: URLRequest) -> URLRequest {
        guard let url = request.url else { return request }
        let stored = cookieStorage.cookies(for: url) ?? []
        let live = session.configuration.httpCookieStorage?.cookies(for: url) ?? []
        var seen = Set<String>()
        var cookies: [HTTPCookie] = []
        for cookie in stored + live where seen.insert("\(cookie.domain)|\(cookie.path)|\(cookie.name)").inserted {
            cookies.append(cookie)
        }
        guard let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] else { return request }
        var request = request
        request.setValue(header, forHTTPHeaderField: "Cookie")
        return request
    }

    private func url(path: String) -> URL {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)!
        }
        let normalized = path.hasPrefix("/") ? path : "/" + path
        let scheme = normalized == "/rui" || normalized.hasPrefix("/rui/") ? "https" : "http"
        return URL(string: "\(scheme)://\(host)\(normalized)")!
    }

    private static func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Captures `Set-Cookie` on redirect responses. `URLSession.data(for:)` only returns the final response,
/// and a login `302` often carries the session cookie.
/// The printer Remote UI certificate is self-signed for the LAN host, so server trust for `host` is accepted.
private final class CookieRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let storage: HTTPCookieStorage
    private let host: String

    init(storage: HTTPCookieStorage, host: String) {
        self.storage = storage
        self.host = host
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust,
              space.host.caseInsensitiveCompare(host) == .orderedSame else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        store(response)
        return request
    }

    func store(_ response: HTTPURLResponse) {
        guard let url = response.url else { return }
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            let name = (key as? String) ?? (key.base as? String)
            let header = (value as? String) ?? (value as? NSString).map { $0 as String }
            guard let name, let header else { continue }
            headers[name] = header
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        guard !cookies.isEmpty else { return }
        storage.cookieAcceptPolicy = .always
        for cookie in cookies {
            storage.setCookie(cookie)
        }
    }
}
