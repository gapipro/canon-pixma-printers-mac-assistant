import XCTest
@testable import G3010Assistant

final class PrinterStatusParsingTests: XCTestCase {
    func testParseIdlePrintStatus() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8" ?>
        <cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/" xmlns:vcn="http://www.canon.com/ns/cmd/2008/07/canon/">
        <ivec:contents>
        <ivec:operation>GetStatusResponse</ivec:operation>
        <ivec:param_set servicetype="print">
        <ivec:status>idle</ivec:status>
        <ivec:status_detail/>
        </ivec:param_set>
        </ivec:contents>
        </cmd>
        """
        let status = try CHMPXML.parseGetStatusResponse(Data(xml.utf8))
        XCTAssertTrue(status.isIdle)
        XCTAssertEqual(status.detail, "idle")
    }
}
