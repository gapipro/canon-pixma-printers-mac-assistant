import XCTest
@testable import G3010Assistant

final class CHMPXMLTests: XCTestCase {
    func testGetStatusPrintXMLContainsOperation() throws {
        let data = CHMPXML.getStatus(serviceType: "print")
        let s = String(data: data, encoding: .utf8)!
        XCTAssertTrue(s.contains("GetStatus"))
        XCTAssertTrue(s.contains("servicetype=\"print\""))
    }

    func testPowerOffXMLMatchesWindowsAssistant() throws {
        let s = String(data: CHMPXML.powerOff(), encoding: .utf8)!
        XCTAssertTrue(s.contains("<ivec:operation>PowerOff</ivec:operation>"))
        XCTAssertTrue(s.contains("servicetype=\"device\""))
    }

    func testParsePowerOffResponse() throws {
        let xml = """
        <?xml version="1.0"?><cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/">
        <ivec:contents><ivec:operation>PowerOffResponse</ivec:operation></ivec:contents></cmd>
        """
        try CHMPXML.parsePowerOffResponse(Data(xml.utf8))
        XCTAssertThrowsError(try CHMPXML.parsePowerOffResponse(Data("<cmd/>".utf8)))
    }
}
