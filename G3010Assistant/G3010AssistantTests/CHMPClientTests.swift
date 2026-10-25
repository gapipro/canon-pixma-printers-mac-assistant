import XCTest
@testable import G3010Assistant

final class CHMPClientTests: XCTestCase {
    func testFetchPrintStatusIdle() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            let xml = """
            <?xml version="1.0"?><cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/">
            <ivec:contents><ivec:operation>GetStatusResponse</ivec:operation>
            <ivec:param_set servicetype="print"><ivec:status>idle</ivec:status></ivec:param_set>
            </ivec:contents></cmd>
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(xml.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = CHMPClient(host: "192.168.1.50", session: URLSession(configuration: config))
        let status = try await client.fetchPrintStatus()
        XCTAssertTrue(status.isIdle)
    }
}
