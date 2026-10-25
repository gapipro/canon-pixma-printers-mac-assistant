import XCTest
@testable import G3010Assistant

final class EndpointMapTests: XCTestCase {
    func testUnmappedActionsReturnNil() {
        for action in AssistantAction.allCases {
            XCTAssertNil(EndpointMap.endpoint(for: action), action.rawValue)
        }
    }
}
