import Foundation

enum EndpointKind: Equatable { case remoteUIForm, chmp }

struct ActionEndpoint: Equatable {
    var kind: EndpointKind
    var path: String
    var method: String
    var bodyTemplate: String // application/x-www-form-urlencoded or CHMP XML
    var successContains: String
}

enum EndpointMap {
    /// Empty until `docs/captures/remote-ui-actions.md` is filled. Replace with concrete literals after capture.
    private static let table: [AssistantAction: ActionEndpoint] = [:]

    static func endpoint(for action: AssistantAction) -> ActionEndpoint? {
        table[action]
    }
}
