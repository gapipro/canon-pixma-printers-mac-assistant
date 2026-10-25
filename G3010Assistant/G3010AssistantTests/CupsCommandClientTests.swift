import XCTest
@testable import G3010Assistant

final class CupsCommandClientTests: XCTestCase {
    func testCommandPayloadsMatchGSeriesTool() {
        XCTAssertEqual(
            CupsCommandClient.payload(for: .cleaning),
            "#CUPS-COMMAND\nClean all\n"
        )
        XCTAssertEqual(
            CupsCommandClient.payload(for: .nozzleCheck),
            "#CUPS-COMMAND\nPrintSelfTestPage\n"
        )
        XCTAssertEqual(
            CupsCommandClient.payload(for: .headAlignment),
            "#CUPS-COMMAND\ncom.canon.autoalignment\n"
        )
        XCTAssertNil(CupsCommandClient.payload(for: .deepCleaning))
        XCTAssertNil(CupsCommandClient.payload(for: .inkFlush))
    }

    func testSupportsOnlyCUPSMappedActions() {
        XCTAssertTrue(CupsCommandClient.supports(.cleaning))
        XCTAssertTrue(CupsCommandClient.supports(.nozzleCheck))
        XCTAssertTrue(CupsCommandClient.supports(.headAlignment))
        XCTAssertFalse(CupsCommandClient.supports(.quietSettings))
    }

    func testPickQueuePrefersG3010Name() {
        let queues = ["HP_Laser", "Canon_G3010_series", "Brother"]
        XCTAssertEqual(CupsCommandClient.pickQueue(from: queues), "Canon_G3010_series")
    }

    func testPickQueueMatchesCanonGSeries() {
        XCTAssertEqual(
            CupsCommandClient.pickQueue(from: ["Epson", "Canon_G3000_series"]),
            "Canon_G3000_series"
        )
        XCTAssertNil(CupsCommandClient.pickQueue(from: ["HP_OfficeJet"]))
    }
}
