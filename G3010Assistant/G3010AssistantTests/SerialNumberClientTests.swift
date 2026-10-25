import XCTest
@testable import G3010Assistant

final class SerialNumberClientTests: XCTestCase {
    /// Captured SNMPv1 GetResponse from a live G3010 (`public` / serial OID).
    private let fixtureResponse = Data(hexString: """
        303602010004067075626c6963a229020101020100020100301e301c060f\
        2b060104018c42010201080103010104094b4c504b3138363630
        """)!

    func testParseSerialFromGetResponse() throws {
        let serial = try SerialNumberClient.parseSerial(from: fixtureResponse)
        XCTAssertEqual(serial, "KLPK18660")
    }

    func testParseThrowsWhenNoOctetString() {
        let bare = Data([0x30, 0x03, 0x02, 0x01, 0x00])
        XCTAssertThrowsError(try SerialNumberClient.parseSerial(from: bare))
    }

    func testBuildGetRequestContainsCommunityAndOID() {
        let request = SerialNumberClient.buildGetRequest(requestID: 1)
        let text = String(decoding: request, as: UTF8.self)
        XCTAssertTrue(text.contains("public"))
        // OID 1.3.6.1.4.1.1602… encodes enterprise 1602 as 0x8c 0x42
        XCTAssertTrue(request.contains(Data([0x8c, 0x42])))
    }
}

private extension Data {
    init?(hexString: String) {
        let hex = hexString.filter { !$0.isWhitespace && $0 != "\\" }
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
