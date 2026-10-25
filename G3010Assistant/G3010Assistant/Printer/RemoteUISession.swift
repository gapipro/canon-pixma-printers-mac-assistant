import Foundation

actor RemoteUISession {
    /// Placeholder path for the Remote UI login POST.
    /// Task 10 replaces this constant from `docs/captures/remote-ui-actions.md` after a live capture.
    static let loginPath = "/"

    /// Placeholder form field name for the admin password (`Password=...`).
    /// Task 10 replaces this constant from `docs/captures/remote-ui-actions.md` after a live capture.
    static let passwordField = "Password"

    let host: String
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage
    private var loggedIn = false

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
        let url = url(path: Self.loginPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded([Self.passwordField: password])

        let (_, response) = try await load(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.authFailed }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AppError.authFailed
        }
        guard (200..<400).contains(http.statusCode) else {
            throw AppError.authFailed
        }
        loggedIn = true
    }

    func perform(_ endpoint: ActionEndpoint) async throws {
        guard loggedIn || endpoint.kind == .chmp else { throw AppError.authFailed }
        let url = url(path: endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        if !endpoint.bodyTemplate.isEmpty {
            request.httpBody = Data(endpoint.bodyTemplate.utf8)
            let contentType = endpoint.kind == .chmp
                ? "application/octet-stream"
                : "application/x-www-form-urlencoded"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await load(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.unreachable(host) }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.http(http.statusCode, body)
        }
        guard body.contains(endpoint.successContains) else {
            throw AppError.parse("response missing \(endpoint.successContains)")
        }
    }

    func remoteUIHomeURL() -> URL {
        URL(string: "http://\(host)/")!
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let redirect = CookieRedirectDelegate(storage: cookieStorage)
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
        return URL(string: "http://\(host)\(normalized)")!
    }

    private static func formEncoded(_ fields: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }
}

/// Captures `Set-Cookie` on redirect responses. `URLSession.data(for:)` only returns the final response,
/// and a login `302` often carries the session cookie.
private final class CookieRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let storage: HTTPCookieStorage

    init(storage: HTTPCookieStorage) {
        self.storage = storage
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
