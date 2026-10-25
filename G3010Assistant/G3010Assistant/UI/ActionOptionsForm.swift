import SwiftUI

/// Submenu controls for a maintenance / settings action.
struct ActionOptionsForm: View {
    let action: AssistantAction
    @Binding var options: ActionOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(action.subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(ActionOptions.instructions(for: action), id: \.self) { step in
                Label(step, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            switch action {
            case .quietSettings:
                quietForm
            case .autoPower:
                autoPowerForm
            case .customSettings:
                customForm
            case .inkNotificationSettings:
                inkForm
            case .headAlignment:
                alignmentForm
            case .rollerCleaning:
                rollerForm
            case .powerOff:
                EmptyView()
            default:
                EmptyView()
            }
        }
    }

    private var quietForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quiet mode")
                .font(.headline)
            Picker("Mode", selection: $options.quiet.mode) {
                ForEach(ActionOptions.QuietMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            if options.quiet.mode == .scheduled {
                HStack {
                    Text("From")
                    timeFields(
                        hour: $options.quiet.startHour,
                        minute: $options.quiet.startMinute
                    )
                    Text("to")
                    timeFields(
                        hour: $options.quiet.endHour,
                        minute: $options.quiet.endMinute
                    )
                }
                .font(.callout)
            }
        }
    }

    private var autoPowerForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto power")
                .font(.headline)
            Toggle("Auto Power On", isOn: $options.autoPower.powerOnEnabled)
            Picker("Auto Power Off", selection: $options.autoPower.powerOffMinutes) {
                ForEach(ActionOptions.AutoPowerOptions.powerOffChoices, id: \.minutes) { choice in
                    Text(choice.title).tag(choice.minutes)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom settings")
                .font(.headline)
            Toggle("Prevent paper abrasion", isOn: $options.custom.preventPaperAbrasion)
            Stepper(
                value: $options.custom.inkDryingLevel,
                in: 1...5
            ) {
                Text("Ink drying wait level: \(options.custom.inkDryingLevel)")
            }
        }
    }

    private var inkForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remaining ink notification")
                .font(.headline)
            Picker("Action", selection: $options.inkNotification.choice) {
                ForEach(ActionOptions.InkNotificationChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.radioGroup)
            Text("After a counter reset, refill tanks to the upper limit line on the tank.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var alignmentForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Print head alignment")
                .font(.headline)
            Picker("Mode", selection: $options.headAlignment) {
                ForEach(ActionOptions.HeadAlignmentChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.radioGroup)
            Text(options.headAlignment.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rollerForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Roller source")
                .font(.headline)
            Picker("Source", selection: $options.rollerSource) {
                ForEach(ActionOptions.RollerSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    private func timeFields(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            TextField("HH", value: hour, format: .number.precision(.integerLength(2)))
                .frame(width: 36)
                .textFieldStyle(.roundedBorder)
                .onChange(of: hour.wrappedValue) { _, new in
                    hour.wrappedValue = min(23, max(0, new))
                }
            Text(":")
            TextField("MM", value: minute, format: .number.precision(.integerLength(2)))
                .frame(width: 36)
                .textFieldStyle(.roundedBorder)
                .onChange(of: minute.wrappedValue) { _, new in
                    minute.wrappedValue = min(59, max(0, new))
                }
        }
    }
}
