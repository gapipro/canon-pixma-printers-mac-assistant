import Network
import XCTest
@testable import G3010Assistant

final class PrinterBrowserTests: XCTestCase {
    func testBrowsesIPPOnLocalDomain() {
        XCTAssertEqual(PrinterBrowser.serviceType, "_ipp._tcp")
        XCTAssertEqual(PrinterBrowser.serviceDomain, "local.")
    }

    func testManualDeviceUsesFixedNameAndModel() {
        let device = PrinterBrowser.manualDevice(host: "192.168.1.20")
        XCTAssertEqual(device, PrinterDevice(name: "Manual", host: "192.168.1.20", model: "G3010"))
        XCTAssertEqual(device.id, "192.168.1.20")
        XCTAssertEqual(device.displayName, "Manual (192.168.1.20)")
    }

    func testFilterMatchesCanonOrG3010InNameOrTXT() {
        XCTAssertTrue(PrinterBrowser.isCanonOrG3010(name: "Canon G3010 series", txt: [:]))
        XCTAssertTrue(PrinterBrowser.isCanonOrG3010(name: "g3010", txt: [:]))
        XCTAssertTrue(PrinterBrowser.isCanonOrG3010(name: "Office", txt: ["ty": "Canon PIXMA"]))
        XCTAssertTrue(PrinterBrowser.isCanonOrG3010(name: "Office", txt: ["usb_MDL": "G3010"]))
        XCTAssertTrue(PrinterBrowser.isCanonOrG3010(name: "Office", txt: ["usb_MFG": "Canon"]))
        XCTAssertFalse(PrinterBrowser.isCanonOrG3010(name: "HP LaserJet", txt: ["ty": "HP LaserJet Pro"]))
        XCTAssertFalse(PrinterBrowser.isCanonOrG3010(name: "G301", txt: [:]))
    }

    func testDevicePrefersTypeThenModelTXT() {
        let fromType = PrinterBrowser.device(
            name: "Canon G3010 series",
            host: "192.168.1.9",
            txt: ["ty": "Canon G3010 series", "usb_MDL": "G3010"]
        )
        XCTAssertEqual(fromType.model, "Canon G3010 series")
        XCTAssertEqual(fromType.name, "Canon G3010 series")
        XCTAssertEqual(fromType.host, "192.168.1.9")

        let fromModel = PrinterBrowser.device(
            name: "Canon",
            host: "printer.local",
            txt: ["usb_MDL": "G3010 series"]
        )
        XCTAssertEqual(fromModel.model, "G3010 series")

        let fallback = PrinterBrowser.device(name: "Canon", host: "10.0.0.4", txt: [:])
        XCTAssertEqual(fallback.model, "G3010")
    }

    func testHostStringReadsIPNameAndSkipsUnresolvedService() {
        let ipv4 = IPv4Address("192.168.1.42")!
        let ipEndpoint = NWEndpoint.hostPort(host: .ipv4(ipv4), port: 631)
        XCTAssertEqual(PrinterBrowser.hostString(from: ipEndpoint), "192.168.1.42")

        let nameEndpoint = NWEndpoint.hostPort(host: .name("CanonG3010.local.", nil), port: 80)
        XCTAssertEqual(PrinterBrowser.hostString(from: nameEndpoint), "CanonG3010.local")

        let service = NWEndpoint.service(
            name: "Canon G3010 series",
            type: "_ipp._tcp.",
            domain: "local.",
            interface: nil
        )
        XCTAssertNil(PrinterBrowser.hostString(from: service))
        XCTAssertNil(PrinterBrowser.hostString(from: nil))
    }

    @MainActor
    func testAddManualPrinterTrimsDedupesAndSurvivesStop() {
        let browser = PrinterBrowser()
        browser.addManualPrinter(ip: "   ")
        XCTAssertTrue(browser.printers.isEmpty)

        browser.addManualPrinter(ip: "  10.1.1.1 ")
        browser.addManualPrinter(ip: "10.0.0.2")
        browser.addManualPrinter(ip: "10.1.1.1")
        XCTAssertEqual(Set(browser.printers.map(\.host)), ["10.1.1.1", "10.0.0.2"])
        XCTAssertTrue(browser.printers.allSatisfy { $0.name == "Manual" && $0.model == "G3010" })

        browser.stop()
        XCTAssertEqual(Set(browser.printers.map(\.host)), ["10.1.1.1", "10.0.0.2"])
    }

    @MainActor
    func testPreviewBrowserHoldsSamplePrinters() {
        let preview = PreviewPrinterBrowser()
        preview.start()
        XCTAssertEqual(preview.printers.count, 1)
        XCTAssertEqual(preview.printers[0].model, "G3010")
        preview.stop()
        XCTAssertEqual(preview.printers.count, 1)

        let empty = PreviewPrinterBrowser(printers: [])
        XCTAssertTrue(empty.printers.isEmpty)
    }
}
