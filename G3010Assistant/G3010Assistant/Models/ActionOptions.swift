import Foundation

/// Per-action submenu choices (Windows Assistant / Remote UI parity).
struct ActionOptions: Equatable {
    var quiet: QuietOptions = .init()
    var autoPower: AutoPowerOptions = .init()
    var custom: CustomOptions = .init()
    var inkNotification: InkNotificationOptions = .init()
    var headAlignment: HeadAlignmentChoice = .automatic
    var rollerSource: RollerSource = .rearTray

    enum QuietMode: String, CaseIterable, Identifiable {
        case off, on, scheduled
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: return "Do not use quiet mode"
            case .on: return "Always use quiet mode"
            case .scheduled: return "Use quiet mode during specified hours"
            }
        }
    }

    struct QuietOptions: Equatable {
        var mode: QuietMode = .on
        var startHour: Int = 21
        var startMinute: Int = 0
        var endHour: Int = 7
        var endMinute: Int = 0
    }

    struct AutoPowerOptions: Equatable {
        var powerOnEnabled: Bool = false
        /// `0` means Auto Power Off is disabled; otherwise minutes until power off.
        var powerOffMinutes: Int = 15

        static let powerOffChoices: [(minutes: Int, title: String)] = [
            (0, "OFF"),
            (15, "15 min."),
            (30, "30 min."),
            (60, "60 min."),
            (120, "120 min."),
            (240, "240 min."),
        ]
    }

    struct CustomOptions: Equatable {
        var preventPaperAbrasion: Bool = false
        /// Remote UI `DRY_LEVEL` (1…5).
        var inkDryingLevel: Int = 3
    }

    enum InkNotificationChoice: String, CaseIterable, Identifiable {
        case enableWithReset
        case disable
        case resetCounterOnly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .enableWithReset: return "Enable ink notification and reset counter"
            case .disable: return "Disable ink notification"
            case .resetCounterOnly: return "Reset remaining ink level count only"
            }
        }
    }

    struct InkNotificationOptions: Equatable {
        var choice: InkNotificationChoice = .resetCounterOnly
    }

    enum HeadAlignmentChoice: String, CaseIterable, Identifiable {
        case automatic
        case printAlignmentValue
        var id: String { rawValue }
        var title: String {
            switch self {
            case .automatic: return "Automatic print head alignment"
            case .printAlignmentValue: return "Print alignment value"
            }
        }
        var detail: String {
            switch self {
            case .automatic: return "Prints a pattern and aligns the head automatically."
            case .printAlignmentValue: return "Prints the current alignment pattern for inspection."
            }
        }
    }

    enum RollerSource: String, CaseIterable, Identifiable {
        case rearTray
        var id: String { rawValue }
        var title: String { "Rear tray / manual feed rollers" }
    }

    /// Instruction steps shown before Execute for wizard-style jobs.
    static func instructions(for action: AssistantAction) -> [String] {
        switch action {
        case .cleaning:
            return [
                "Load plain paper if you plan to print a nozzle check afterward.",
                "Cleaning uses a small amount of ink.",
            ]
        case .deepCleaning:
            return [
                "Try normal Cleaning first.",
                "Deep Cleaning uses a large amount of ink.",
            ]
        case .nozzleCheck:
            return [
                "Load one sheet of A4 or Letter plain paper.",
                "After printing, compare the pattern to the clogged / clear examples.",
            ]
        case .inkFlush:
            return [
                "Ensure tanks are adequately filled (about 50% or more).",
                "Ink Flush / system cleaning uses a large amount of ink.",
            ]
        case .bottomPlateCleaning:
            return [
                "Fold one sheet of A4/Letter plain paper as shown in the printer manual.",
                "Load the folded sheet in the rear tray, then start.",
            ]
        case .rollerCleaning:
            return [
                "Remove paper from the tray when prompted by the printer.",
                "Then load 3+ sheets of plain paper to finish roller cleaning.",
            ]
        case .headAlignment:
            return [
                "Load one sheet of A4 or Letter plain paper.",
                "Do not open covers until alignment finishes.",
            ]
        case .powerOff:
            return [
                "Turns the printer off over the network (same as Windows Power Off).",
                "You will need to power it back on from the printer to use it again.",
            ]
        default:
            return []
        }
    }
}
