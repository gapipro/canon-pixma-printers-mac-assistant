import SwiftUI

enum AssistantAction: String, CaseIterable, Identifiable {
    case cleaning
    case deepCleaning
    case headAlignment
    case nozzleCheck
    case inkFlush
    case inkNotificationSettings
    case bottomPlateCleaning
    case rollerCleaning
    case powerOff
    case autoPower
    case quietSettings
    case customSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleaning: return "Cleaning"
        case .deepCleaning: return "Deep Cleaning"
        case .headAlignment: return "Print Head Alignment"
        case .nozzleCheck: return "Nozzle Check"
        case .inkFlush: return "Ink Flush"
        case .inkNotificationSettings: return "Remaining Ink Notification Settings"
        case .bottomPlateCleaning: return "Bottom Plate Cleaning"
        case .rollerCleaning: return "Roller Cleaning"
        case .powerOff: return "Power Off"
        case .autoPower: return "Auto Power On/Off"
        case .quietSettings: return "Quiet Settings"
        case .customSettings: return "Custom Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .cleaning: return "Clear smudges and streaks from print results."
        case .deepCleaning: return "Unclog nozzles when normal cleaning is not enough."
        case .headAlignment: return "Fix misaligned colors and lines."
        case .nozzleCheck: return "Print a pattern to check for clogged nozzles."
        case .inkFlush: return "Fill ink tubes and print head with ink."
        case .inkNotificationSettings: return "Configure ink alerts and reset the ink level counter."
        case .bottomPlateCleaning: return "Prevent smudges from the bottom plate."
        case .rollerCleaning: return "Clean the paper feed roller."
        case .powerOff: return "Turn the printer off."
        case .autoPower: return "Configure automatic power on/off."
        case .quietSettings: return "Reduce operating noise."
        case .customSettings: return "Change operational options."
        }
    }

    var isInkHeavy: Bool {
        self == .deepCleaning || self == .inkFlush
    }

    var iconTint: Color {
        switch self {
        case .cleaning: return .primary
        case .deepCleaning: return .cyan
        case .headAlignment: return .blue
        case .nozzleCheck: return .indigo
        case .inkFlush: return .teal
        case .inkNotificationSettings: return .orange
        case .bottomPlateCleaning, .rollerCleaning: return .yellow
        case .powerOff, .autoPower, .customSettings: return .secondary
        case .quietSettings: return .blue
        }
    }

    static var leftColumn: [AssistantAction] {
        [.cleaning, .deepCleaning, .headAlignment, .nozzleCheck, .inkFlush, .inkNotificationSettings]
    }

    static var rightColumn: [AssistantAction] {
        [.bottomPlateCleaning, .rollerCleaning, .powerOff, .autoPower, .quietSettings, .customSettings]
    }
}
