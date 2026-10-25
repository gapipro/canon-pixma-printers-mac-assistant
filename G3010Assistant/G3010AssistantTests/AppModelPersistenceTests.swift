import XCTest
@testable import G3010Assistant

@MainActor
final class AppModelPersistenceTests: XCTestCase {
    private let key = "lastPrinterHost"
    private var previousHost: String?

    override func setUp() {
        super.setUp()
        previousHost = UserDefaults.standard.string(forKey: key)
    }

    override func tearDown() {
        if let previousHost {
            UserDefaults.standard.set(previousHost, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testManualAddPersistsHost() {
        let model = AppModel(previewPrinters: [])
        model.addManualPrinter(ip: "  10.8.8.8  ")
        XCTAssertEqual(model.selectedPrinter?.host, "10.8.8.8")
        XCTAssertEqual(model.selectedPrinter?.name, "Manual")
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "10.8.8.8")
    }

    func testRestoresMatchingHostAfterPrintersAppear() {
        UserDefaults.standard.set("10.8.8.8", forKey: key)
        let other = PrinterDevice(name: "Other", host: "10.8.8.1", model: "G3010")
        let match = PrinterDevice(name: "Canon G3010 series", host: "10.8.8.8", model: "G3010")
        let model = AppModel(previewPrinters: [other, match])
        XCTAssertEqual(model.selectedPrinter, match)
    }

    func testUnmatchedHostStaysStoredUntilItAppears() {
        UserDefaults.standard.set("10.9.9.9", forKey: key)
        let other = PrinterDevice(name: "Other", host: "10.8.8.1", model: "G3010")
        let model = AppModel(previewPrinters: [other])
        XCTAssertEqual(model.selectedPrinter, other)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "10.9.9.9")
    }
}
