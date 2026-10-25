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
    /// Captured from the G3010 Remote UI. `bodyTemplate` omits `SBID`; `RemoteUISession` appends it.
    /// Job-kick rows use `RW_OK`. `perform` also accepts `RW_POLLING` and rejects `RW_NG`.
    /// Quiet mode posts `SILENT_MODE=ON` (reduce operating noise).
    /// Ink notification resets the counter (`INK_CNT_RESET=SET`).
    /// Auto power writes the power-save schedule. A live SET returns `RESULT` `RD_PAGE_UT`.
    /// Power Off and Custom Settings are omitted. This firmware has no CGI for those actions.
    /// `endpoint(for:)` returns nil, and ActionFlow uses `.endpointMissing` to open Remote UI in Safari.
    private static let table: [AssistantAction: ActionEndpoint] = [
        .cleaning: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_normal_cln.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .deepCleaning: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_deep_cln.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .headAlignment: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_auto_regi.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .nozzleCheck: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_nozzle_check.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .inkFlush: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_system_cln.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .inkNotificationSettings: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/detect_ink_end.cgi",
            method: "POST",
            bodyTemplate: "SETINFO=0&INK_CNT_RESET=SET",
            successContains: "RW_OK"
        ),
        .bottomPlateCleaning: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_platen_cln.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .rollerCleaning: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_roller_mf_cln.cgi",
            method: "POST",
            bodyTemplate: "",
            successContains: "RW_OK"
        ),
        .autoPower: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/ut_data.cgi",
            method: "POST",
            bodyTemplate: "SETINFO=0&POWER_SAVE_OFF=ON&POWER_SAVE_TIME=15",
            successContains: "RD_PAGE_UT"
        ),
        .quietSettings: ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/silent_mode.cgi",
            method: "POST",
            bodyTemplate: "SILENT_MODE=ON",
            successContains: "RW_OK"
        ),
    ]

    static func endpoint(for action: AssistantAction) -> ActionEndpoint? {
        table[action]
    }
}
