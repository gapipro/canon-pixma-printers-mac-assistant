import XCTest
@testable import G3010Assistant

final class EndpointMapTests: XCTestCase {
    func testDefaultJobEndpoints() {
        XCTAssertEqual(EndpointMap.endpoint(for: .cleaning)?.path, "/rui/ut_normal_cln.cgi")
        XCTAssertEqual(EndpointMap.endpoint(for: .deepCleaning)?.path, "/rui/ut_deep_cln.cgi")
        XCTAssertEqual(EndpointMap.endpoint(for: .nozzleCheck)?.path, "/rui/ut_nozzle_check.cgi")
        XCTAssertEqual(EndpointMap.endpoint(for: .inkFlush)?.path, "/rui/ut_system_cln.cgi")
        XCTAssertEqual(EndpointMap.endpoint(for: .bottomPlateCleaning)?.path, "/rui/ut_platen_cln.cgi")
        XCTAssertEqual(EndpointMap.endpoint(for: .rollerCleaning)?.path, "/rui/ut_roller_mf_cln.cgi")
        let power = EndpointMap.endpoint(for: .powerOff)
        XCTAssertEqual(power?.kind, .chmp)
        XCTAssertEqual(power?.path, "/canon/ij/command2/port1")
        XCTAssertEqual(power?.successContains, "PowerOffResponse")
    }

    func testQuietModeBodies() {
        var options = ActionOptions()
        options.quiet.mode = .off
        XCTAssertEqual(EndpointMap.endpoint(for: .quietSettings, options: options)?.bodyTemplate, "SILENT_MODE=OFF")

        options.quiet.mode = .on
        XCTAssertEqual(EndpointMap.endpoint(for: .quietSettings, options: options)?.bodyTemplate, "SILENT_MODE=ON")

        options.quiet.mode = .scheduled
        options.quiet.startHour = 21
        options.quiet.startMinute = 5
        options.quiet.endHour = 7
        options.quiet.endMinute = 0
        XCTAssertEqual(
            EndpointMap.endpoint(for: .quietSettings, options: options)?.bodyTemplate,
            "SILENT_MODE=RANGE&ST_TIME_H=21&ST_TIME_M=05&END_TIME_H=07&END_TIME_M=00"
        )
    }

    func testAutoPowerAndCustomUseMachininfo() {
        var options = ActionOptions()
        options.autoPower.powerOnEnabled = true
        options.autoPower.powerOffMinutes = 60
        let power = EndpointMap.endpoint(for: .autoPower, options: options)
        XCTAssertEqual(power?.path, "/rui/machininfo_data.cgi")
        XCTAssertEqual(
            power?.bodyTemplate,
            "SETINFO=0&POWER_SAVE_OFF=ON&POWER_SAVE_TIME=60&POWER_SAVE_ON=ON"
        )
        XCTAssertEqual(power?.successContains, "RW_PAGE_HARD")

        options.custom.preventPaperAbrasion = true
        options.custom.inkDryingLevel = 4
        let custom = EndpointMap.endpoint(for: .customSettings, options: options)
        XCTAssertEqual(custom?.path, "/rui/machininfo_data.cgi")
        XCTAssertEqual(custom?.bodyTemplate, "SETINFO=0&PAPER_GAP=ON&DRY_LEVEL=4")
    }

    func testInkNotificationChoices() {
        var options = ActionOptions()
        options.inkNotification.choice = .enableWithReset
        XCTAssertEqual(
            EndpointMap.endpoint(for: .inkNotificationSettings, options: options)?.bodyTemplate,
            "SETINFO=0&DETECT_INK_END=SET&INK_CNT_RESET=SET"
        )
        options.inkNotification.choice = .disable
        XCTAssertEqual(
            EndpointMap.endpoint(for: .inkNotificationSettings, options: options)?.bodyTemplate,
            "SETINFO=0&DETECT_INK_END=CLEAR"
        )
        options.inkNotification.choice = .resetCounterOnly
        XCTAssertEqual(
            EndpointMap.endpoint(for: .inkNotificationSettings, options: options)?.bodyTemplate,
            "SETINFO=0&INK_CNT_RESET=SET"
        )
    }

    func testHeadAlignmentModes() {
        var options = ActionOptions()
        options.headAlignment = .automatic
        XCTAssertEqual(EndpointMap.endpoint(for: .headAlignment, options: options)?.path, "/rui/ut_auto_regi.cgi")
        options.headAlignment = .printAlignmentValue
        XCTAssertEqual(EndpointMap.endpoint(for: .headAlignment, options: options)?.path, "/rui/ut_regi_print.cgi")
    }

    func testAllActionsMapped() {
        XCTAssertNotNil(EndpointMap.endpoint(for: .customSettings))
        XCTAssertEqual(AssistantAction.allCases.count, 12)
        let mapped = AssistantAction.allCases.filter { EndpointMap.endpoint(for: $0) != nil }
        XCTAssertEqual(mapped.count, 12)
    }
}
