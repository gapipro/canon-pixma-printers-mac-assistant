import XCTest
@testable import G3010Assistant

final class EndpointMapTests: XCTestCase {
    func testEveryActionMapped() {
        let expected: [AssistantAction: (path: String, body: String, success: String)] = [
            .cleaning: ("/rui/ut_normal_cln.cgi", "", "RW_OK"),
            .deepCleaning: ("/rui/ut_deep_cln.cgi", "", "RW_OK"),
            .headAlignment: ("/rui/ut_auto_regi.cgi", "", "RW_OK"),
            .nozzleCheck: ("/rui/ut_nozzle_check.cgi", "", "RW_OK"),
            .inkFlush: ("/rui/ut_system_cln.cgi", "", "RW_OK"),
            .inkNotificationSettings: ("/rui/detect_ink_end.cgi", "SETINFO=0&INK_CNT_RESET=SET", "RW_OK"),
            .bottomPlateCleaning: ("/rui/ut_platen_cln.cgi", "", "RW_OK"),
            .rollerCleaning: ("/rui/ut_roller_mf_cln.cgi", "", "RW_OK"),
            .autoPower: ("/rui/ut_data.cgi", "SETINFO=0&POWER_SAVE_OFF=ON&POWER_SAVE_TIME=15", "RD_PAGE_UT"),
            .quietSettings: ("/rui/silent_mode.cgi", "SILENT_MODE=ON", "RW_OK"),
        ]

        XCTAssertEqual(AssistantAction.allCases.count, 12)
        XCTAssertNil(EndpointMap.endpoint(for: .powerOff))
        XCTAssertNil(EndpointMap.endpoint(for: .customSettings))
        let mapped = AssistantAction.allCases.filter { EndpointMap.endpoint(for: $0) != nil }
        XCTAssertEqual(mapped.count, 10)
        XCTAssertEqual(Set(expected.keys), Set(mapped))
        for action in mapped {
            let endpoint = EndpointMap.endpoint(for: action)
            let row = expected[action]
            XCTAssertNotNil(endpoint, action.rawValue)
            XCTAssertEqual(endpoint?.kind, .remoteUIForm, action.rawValue)
            XCTAssertEqual(endpoint?.method, "POST", action.rawValue)
            XCTAssertEqual(endpoint?.path, row?.path, action.rawValue)
            XCTAssertEqual(endpoint?.bodyTemplate, row?.body, action.rawValue)
            XCTAssertEqual(endpoint?.successContains, row?.success, action.rawValue)
            XCTAssertFalse(endpoint?.bodyTemplate.contains("SBID") == true, action.rawValue)
            XCTAssertTrue(endpoint?.path.hasPrefix("/rui/") == true, action.rawValue)
        }
    }
}
