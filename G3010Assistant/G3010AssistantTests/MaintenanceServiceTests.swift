import XCTest
@testable import G3010Assistant

final class MaintenanceServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRunReachesMappedActionWhenIdle() async {
        stubPrintStatus("idle")
        let service = makeService()
        do {
            try await service.run(.cleaning)
            XCTFail("expected throw")
        } catch let e as AppError {
            XCTAssertEqual(e, .authFailed)
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testEnsureIdleThrowsUnreachableWhenCHMPConflictsAndRemoteUIFails() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("conflict".utf8))
        }
        do {
            try await makeService().ensureIdle()
            XCTFail("expected unreachable")
        } catch let error as AppError {
            XCTAssertEqual(error, .unreachable("192.168.1.50"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testEnsureIdleThrowsUnreachableWhenCHMPTimesOutAndRemoteUIFails() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        do {
            try await makeService().ensureIdle()
            XCTFail("expected unreachable")
        } catch let error as AppError {
            XCTAssertEqual(error, .unreachable("192.168.1.50"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testEnsureIdleAcceptsRemoteUIBSTStateZeroWhenCHMPFails() async throws {
        let remote = RemoteUISession(host: "192.168.1.50", session: mockSession())
        try await login(remote, bst: "0", prninfoError: nil)
        let service = MaintenanceService(
            chmp: CHMPClient(host: "192.168.1.50", session: mockSession()),
            remote: remote
        )
        try await service.ensureIdle()
    }

    func testEnsureIdleThrowsBusyWhenRemoteUIBSTStateIsNonZero() async throws {
        let remote = RemoteUISession(host: "192.168.1.50", session: mockSession())
        try await login(remote, bst: "2", prninfoError: nil)
        let service = MaintenanceService(
            chmp: CHMPClient(host: "192.168.1.50", session: mockSession()),
            remote: remote
        )
        do {
            try await service.ensureIdle()
            XCTFail("expected busy")
        } catch let error as AppError {
            XCTAssertEqual(error, .busy("BST_STATE != 0"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testEnsureIdleThrowsUnreachableWhenRemoteUIStatusFails() async throws {
        let remote = RemoteUISession(host: "192.168.1.50", session: mockSession())
        try await login(remote, bst: "0", prninfoError: URLError(.cannotConnectToHost))
        let service = MaintenanceService(
            chmp: CHMPClient(host: "192.168.1.50", session: mockSession()),
            remote: remote
        )
        do {
            try await service.ensureIdle()
            XCTFail("expected unreachable")
        } catch let error as AppError {
            XCTAssertEqual(error, .unreachable("192.168.1.50"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testRunThrowsBusyWhenPrinterIsNotIdle() async {
        stubPrintStatus("printing")
        let service = makeService()
        do {
            try await service.run(.cleaning)
            XCTFail("expected throw")
        } catch let e as AppError {
            XCTAssertEqual(e, .busy("printing"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testEnsureIdleSucceedsWhenIdle() async throws {
        stubPrintStatus("idle")
        let service = makeService()
        try await service.ensureIdle()
    }

    func testStatusReturnsFetchedPrintStatus() async throws {
        stubPrintStatus("idle")
        let service = makeService()
        let status = try await service.status()
        XCTAssertEqual(status, PrinterStatus(isIdle: true, detail: "idle", model: nil))
    }

    private func login(_ remote: RemoteUISession, bst: String, prninfoError: (any Error)?) async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/canon/ij/command2/port1" {
                let response = HTTPURLResponse(url: url, statusCode: 409, httpVersion: nil, headerFields: nil)!
                return (response, Data("conflict".utf8))
            }
            if url.path == "/rui/prninfo_data.cgi" {
                if let prninfoError { throw prninfoError }
                let xml = "<response><BST_STATE>\(bst)</BST_STATE></response>"
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(xml.utf8))
            }
            if url.path == "/rui/sendpw.cgi" {
                let html = "<input type=\"hidden\" name=\"SBID\" value=\"idleSBID\">"
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(html.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("ok".utf8))
        }
        try await remote.login(password: "secret")
    }

    private func makeService() -> MaintenanceService {
        MaintenanceService(
            chmp: CHMPClient(host: "192.168.1.50", session: mockSession()),
            remote: RemoteUISession(host: "192.168.1.50", session: mockSession())
        )
    }

    private func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func stubPrintStatus(_ status: String) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.httpMethod == "POST" {
                return (response, Data())
            }
            let xml = """
            <?xml version="1.0"?><cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/">
            <ivec:contents><ivec:operation>GetStatusResponse</ivec:operation>
            <ivec:param_set servicetype="print"><ivec:status>\(status)</ivec:status></ivec:param_set>
            </ivec:contents></cmd>
            """
            return (response, Data(xml.utf8))
        }
    }
}
