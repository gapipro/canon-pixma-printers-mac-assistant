import XCTest
@testable import G3010Assistant

final class CHMPXMLTests: XCTestCase {
    func testGetStatusPrintXMLContainsOperation() throws {
        let data = CHMPXML.getStatus(serviceType: "print")
        let s = String(data: data, encoding: .utf8)!
        XCTAssertTrue(s.contains("GetStatus"))
        XCTAssertTrue(s.contains("servicetype=\"print\""))
    }
}
