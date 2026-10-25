import XCTest
@testable import G3010Assistant

final class RemoteUISessionTests: XCTestCase {
    private var keychainHosts: [String] = []

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        for host in keychainHosts {
            KeychainStore.deletePassword(forHost: host)
        }
        keychainHosts.removeAll()
        super.tearDown()
    }

    func testLoginPostsPasswordThenPerformSendsCookie() async throws {
        let log = ExchangeLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request)
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Set-Cookie": "sess=abc; Path=/"]
                )!
                return (response, Data("ok".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("<html>Utilities</html>".utf8))
        }

        let session = makeSession()
        try await session.login(password: "secret")
        try await session.perform(ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/utilities",
            method: "GET",
            bodyTemplate: "",
            successContains: "Utilities"
        ))

        let exchanges = log.all()
        XCTAssertEqual(exchanges.count, 2)
        XCTAssertEqual(exchanges[0].method, "POST")
        XCTAssertEqual(exchanges[0].url, "http://192.168.1.50/")
        XCTAssertEqual(exchanges[0].contentType, "application/x-www-form-urlencoded")
        XCTAssertEqual(formFields(exchanges[0].body ?? "")["Password"], "secret")
        XCTAssertEqual(exchanges[1].method, "GET")
        XCTAssertEqual(exchanges[1].url, "http://192.168.1.50/rui/utilities")
        XCTAssertTrue(exchanges[1].cookie?.contains("sess=abc") == true)
    }

    func testLoginAcceptsRedirectAndKeepsSessionCookie() async throws {
        let log = ExchangeLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request)
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 302,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Location": "http://192.168.1.50/portal",
                        "Set-Cookie": "sess=from302; Path=/",
                    ]
                )!
                return (response, Data())
            }
            if url.path == "/portal" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (response, Data("portal".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("Utilities".utf8))
        }

        let session = makeSession()
        try await session.login(password: "secret")
        try await session.perform(ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/utilities",
            method: "GET",
            bodyTemplate: "",
            successContains: "Utilities"
        ))

        let perform = log.all().last
        XCTAssertEqual(perform?.url, "http://192.168.1.50/rui/utilities")
        XCTAssertTrue(perform?.cookie?.contains("sess=from302") == true)
    }

    func testLoginPercentEncodesPassword() async throws {
        let log = ExchangeLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request)
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("ok".utf8))
        }

        let session = makeSession()
        try await session.login(password: "a b&c+")
        XCTAssertEqual(formFields(log.all()[0].body ?? "")["Password"], "a b&c+")
    }

    func testLoginThrowsAuthFailedOnUnauthorized() async {
        var calls = 0
        MockURLProtocol.requestHandler = { request in
            calls += 1
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("denied".utf8))
        }

        let session = makeSession()
        do {
            try await session.login(password: "nope")
            XCTFail("expected authFailed")
        } catch let error as AppError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }

        do {
            try await session.perform(ActionEndpoint(
                kind: .remoteUIForm,
                path: "/rui/utilities",
                method: "GET",
                bodyTemplate: "",
                successContains: "Utilities"
            ))
            XCTFail("expected authFailed")
        } catch let error as AppError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(calls, 1)
    }

    func testLoginThrowsUnreachableWhenHostDoesNotConnect() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        let session = makeSession(host: "10.0.0.8")
        do {
            try await session.login(password: "secret")
            XCTFail("expected unreachable")
        } catch let error as AppError {
            XCTAssertEqual(error, .unreachable("10.0.0.8"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPerformRemoteUIRequiresLogin() async {
        var called = false
        MockURLProtocol.requestHandler = { request in
            called = true
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("Utilities".utf8))
        }
        let session = makeSession()
        do {
            try await session.perform(ActionEndpoint(
                kind: .remoteUIForm,
                path: "/rui/utilities",
                method: "GET",
                bodyTemplate: "",
                successContains: "Utilities"
            ))
            XCTFail("expected authFailed")
        } catch let error as AppError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertFalse(called)
    }

    func testPerformCHMPWithoutLoginPostsBody() async throws {
        let log = ExchangeLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request)
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("<ok>done</ok>".utf8))
        }
        let session = makeSession()
        try await session.perform(ActionEndpoint(
            kind: .chmp,
            path: "/canon/ij/command2/port1",
            method: "POST",
            bodyTemplate: "<cmd/>",
            successContains: "done"
        ))
        let exchange = try XCTUnwrap(log.all().first)
        XCTAssertEqual(exchange.method, "POST")
        XCTAssertEqual(exchange.url, "http://192.168.1.50/canon/ij/command2/port1")
        XCTAssertEqual(exchange.body, "<cmd/>")
        XCTAssertEqual(exchange.contentType, "application/octet-stream")
    }

    func testPerformThrowsWhenSuccessMarkerMissing() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (response, Data("ok".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("still on the login page".utf8))
        }
        let session = makeSession()
        try await session.login(password: "secret")
        do {
            try await session.perform(ActionEndpoint(
                kind: .remoteUIForm,
                path: "/rui/utilities",
                method: "GET",
                bodyTemplate: "",
                successContains: "Utilities"
            ))
            XCTFail("expected parse error")
        } catch let error as AppError {
            guard case .parse(let message) = error else {
                XCTFail("expected parse, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Utilities"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPerformThrowsHTTPStatus() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (response, Data("ok".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("boom".utf8))
        }
        let session = makeSession()
        try await session.login(password: "secret")
        do {
            try await session.perform(ActionEndpoint(
                kind: .remoteUIForm,
                path: "/rui/utilities",
                method: "POST",
                bodyTemplate: "a=1",
                successContains: "Utilities"
            ))
            XCTFail("expected http error")
        } catch let error as AppError {
            XCTAssertEqual(error, .http(500, "boom"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testRemoteUIHomeURL() async {
        let session = RemoteUISession(host: "192.168.1.50", session: .shared)
        let url = await session.remoteUIHomeURL()
        XCTAssertEqual(url.absoluteString, "http://192.168.1.50/")
    }

    func testKeychainSaveLoadReplaceAndDelete() {
        let host = reserveKeychainHost()
        XCTAssertNil(KeychainStore.password(forHost: host))
        KeychainStore.savePassword("p@ss word", forHost: host)
        XCTAssertEqual(KeychainStore.password(forHost: host), "p@ss word")
        KeychainStore.savePassword("next", forHost: host)
        XCTAssertEqual(KeychainStore.password(forHost: host), "next")
        KeychainStore.deletePassword(forHost: host)
        XCTAssertNil(KeychainStore.password(forHost: host))
    }

    func testKeychainPasswordsAreScopedByHost() {
        let hostA = reserveKeychainHost()
        let hostB = reserveKeychainHost()
        KeychainStore.savePassword("alpha", forHost: hostA)
        KeychainStore.savePassword("beta", forHost: hostB)
        XCTAssertEqual(KeychainStore.password(forHost: hostA), "alpha")
        XCTAssertEqual(KeychainStore.password(forHost: hostB), "beta")
    }

    private func reserveKeychainHost() -> String {
        let host = "unit-test-\(UUID().uuidString).local"
        keychainHosts.append(host)
        KeychainStore.deletePassword(forHost: host)
        return host
    }

    private func makeSession(host: String = "192.168.1.50") -> RemoteUISession {
        let config = RemoteUISession.makeSessionConfiguration()
        config.protocolClasses = [MockURLProtocol.self]
        return RemoteUISession(host: host, session: URLSession(configuration: config))
    }

    private func formFields(_ body: String) -> [String: String] {
        var fields: [String: String] = [:]
        for item in URLComponents(string: "http://localhost/?\(body)")?.queryItems ?? [] {
            fields[item.name] = item.value ?? ""
        }
        return fields
    }
}

private struct Exchange {
    var method: String?
    var url: String?
    var contentType: String?
    var cookie: String?
    var body: String?
}

private final class ExchangeLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Exchange] = []

    func add(_ request: URLRequest) {
        let item = Exchange(
            method: request.httpMethod,
            url: request.url?.absoluteString,
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            cookie: request.value(forHTTPHeaderField: "Cookie"),
            body: Self.readBody(request)
        )
        lock.lock()
        items.append(item)
        lock.unlock()
    }

    func all() -> [Exchange] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    private static func readBody(_ request: URLRequest) -> String? {
        let data: Data?
        if let httpBody = request.httpBody {
            data = httpBody
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = Data()
            var chunk = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&chunk, maxLength: chunk.count)
                if count < 0 { return nil }
                if count == 0 { break }
                buffer.append(chunk, count: count)
            }
            data = buffer
        } else {
            data = nil
        }
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
