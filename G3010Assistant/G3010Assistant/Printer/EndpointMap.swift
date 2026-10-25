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
    /// Builds the Remote UI request for an action using submenu options.
    /// `bodyTemplate` omits `SBID`; `RemoteUISession` appends it.
    /// Job-kick rows use `RW_OK` (perform also accepts `RW_POLLING`).
    static func endpoint(for action: AssistantAction, options: ActionOptions = ActionOptions()) -> ActionEndpoint? {
        switch action {
        case .cleaning:
            return job("/rui/ut_normal_cln.cgi")
        case .deepCleaning:
            return job("/rui/ut_deep_cln.cgi")
        case .nozzleCheck:
            return job("/rui/ut_nozzle_check.cgi")
        case .inkFlush:
            return job("/rui/ut_system_cln.cgi")
        case .bottomPlateCleaning:
            return job("/rui/ut_platen_cln.cgi")
        case .rollerCleaning:
            switch options.rollerSource {
            case .rearTray:
                return job("/rui/ut_roller_mf_cln.cgi")
            }
        case .headAlignment:
            switch options.headAlignment {
            case .automatic:
                return job("/rui/ut_auto_regi.cgi")
            case .printAlignmentValue:
                return job("/rui/ut_regi_print.cgi")
            }
        case .quietSettings:
            return quietEndpoint(options.quiet)
        case .autoPower:
            return autoPowerEndpoint(options.autoPower)
        case .customSettings:
            return customEndpoint(options.custom)
        case .inkNotificationSettings:
            return inkNotificationEndpoint(options.inkNotification)
        case .powerOff:
            // Windows XML targets device PowerOff. On G3010 this is POSTed to command2/port1;
            // the TCP session then drops as the printer shuts down (no reliable GET response).
            return ActionEndpoint(
                kind: .chmp,
                path: "/canon/ij/command2/port1",
                method: "POST",
                bodyTemplate: "",
                successContains: "PowerOffResponse"
            )
        }
    }

    /// Legacy single-endpoint lookup (default options).
    static func endpoint(for action: AssistantAction) -> ActionEndpoint? {
        endpoint(for: action, options: ActionOptions())
    }

    private static func job(_ path: String) -> ActionEndpoint {
        ActionEndpoint(kind: .remoteUIForm, path: path, method: "POST", bodyTemplate: "", successContains: "RW_OK")
    }

    private static func quietEndpoint(_ options: ActionOptions.QuietOptions) -> ActionEndpoint {
        let body: String
        switch options.mode {
        case .off:
            body = "SILENT_MODE=OFF"
        case .on:
            body = "SILENT_MODE=ON"
        case .scheduled:
            body = [
                "SILENT_MODE=RANGE",
                "ST_TIME_H=\(pad2(options.startHour))",
                "ST_TIME_M=\(pad2(options.startMinute))",
                "END_TIME_H=\(pad2(options.endHour))",
                "END_TIME_M=\(pad2(options.endMinute))",
            ].joined(separator: "&")
        }
        return ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/silent_mode.cgi",
            method: "POST",
            bodyTemplate: body,
            successContains: "RW_OK"
        )
    }

    private static func autoPowerEndpoint(_ options: ActionOptions.AutoPowerOptions) -> ActionEndpoint {
        let offEnabled = options.powerOffMinutes != 0
        let body = [
            "SETINFO=0",
            "POWER_SAVE_OFF=\(offEnabled ? "ON" : "OFF")",
            "POWER_SAVE_TIME=\(options.powerOffMinutes)",
            "POWER_SAVE_ON=\(options.powerOnEnabled ? "ON" : "OFF")",
        ].joined(separator: "&")
        return ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/machininfo_data.cgi",
            method: "POST",
            bodyTemplate: body,
            successContains: "RW_PAGE_HARD"
        )
    }

    private static func customEndpoint(_ options: ActionOptions.CustomOptions) -> ActionEndpoint {
        let level = min(5, max(1, options.inkDryingLevel))
        let body = [
            "SETINFO=0",
            "PAPER_GAP=\(options.preventPaperAbrasion ? "ON" : "OFF")",
            "DRY_LEVEL=\(level)",
        ].joined(separator: "&")
        return ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/machininfo_data.cgi",
            method: "POST",
            bodyTemplate: body,
            successContains: "RW_PAGE_HARD"
        )
    }

    private static func inkNotificationEndpoint(_ options: ActionOptions.InkNotificationOptions) -> ActionEndpoint {
        let body: String
        switch options.choice {
        case .enableWithReset:
            body = "SETINFO=0&DETECT_INK_END=SET&INK_CNT_RESET=SET"
        case .disable:
            body = "SETINFO=0&DETECT_INK_END=CLEAR"
        case .resetCounterOnly:
            body = "SETINFO=0&INK_CNT_RESET=SET"
        }
        return ActionEndpoint(
            kind: .remoteUIForm,
            path: "/rui/detect_ink_end.cgi",
            method: "POST",
            bodyTemplate: body,
            successContains: "RW_OK"
        )
    }

    private static func pad2(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
