import XCTest
@testable import G3010Assistant

final class AssistantActionTests: XCTestCase {
    func testAllTwelveActionsExist() {
        XCTAssertEqual(AssistantAction.allCases.count, 12)
        XCTAssertTrue(AssistantAction.allCases.contains(.cleaning))
        XCTAssertTrue(AssistantAction.allCases.contains(.inkFlush))
        XCTAssertTrue(AssistantAction.inkFlush.isInkHeavy)
        XCTAssertTrue(AssistantAction.deepCleaning.isInkHeavy)
        XCTAssertFalse(AssistantAction.nozzleCheck.isInkHeavy)
    }
}
