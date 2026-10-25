import XCTest
@testable import G3010Assistant

final class MaintenanceServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRunThrowsWhenUnmapped() async {
        stubPrintStatus("idle")
        let service = makeService()
        do {
            try await service.run(.cleaning)
            XCTFail("expected throw")
        } catch let e as AppError {
            XCTAssertEqual(e, .endpointMissing(.cleaning))
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
