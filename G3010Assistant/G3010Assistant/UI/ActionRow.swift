import SwiftUI

struct ActionRow: View {
    let action: AssistantAction
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                ActionIconView(action: action)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.leading)
                    Text(action.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }
}

/// Compact original icon inspired by the Windows Assistant layout (not Canon artwork).
struct ActionIconView: View {
    let action: AssistantAction

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
                )

            iconContent
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch action {
        case .cleaning:
            printHeadGlyph(drops: [.black, .black.opacity(0.55)])
        case .deepCleaning:
            printHeadGlyph(drops: [.cyan, .pink, .yellow])
        case .headAlignment:
            alignmentSheet
        case .nozzleCheck:
            nozzleSheet
        case .inkFlush:
            inkTanks
        case .inkNotificationSettings:
            inkAlerts
        case .bottomPlateCleaning, .rollerCleaning:
            rollerGlyph
        case .powerOff:
            Image(systemName: "power")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(action.iconTint)
        case .autoPower:
            Image(systemName: "clock.badge")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(action.iconTint)
        case .quietSettings:
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(action.iconTint)
        case .customSettings:
            Image(systemName: "printer.fill")
                .font(.system(size: 22))
                .foregroundStyle(action.iconTint)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .bold))
                        .padding(2)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 4, y: 4)
                }
        }
    }

    private func printHeadGlyph(drops: [Color]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(Array(drops.enumerated()), id: \.offset) { _, color in
                    Capsule()
                        .fill(color)
                        .frame(width: 6, height: 10)
                }
            }
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                )
                .frame(width: 28, height: 16)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.primary.opacity(0.45))
                                .frame(width: 2, height: 4)
                        }
                    }
                    .offset(y: 3)
                }
        }
    }

    private var alignmentSheet: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                .frame(width: 30, height: 34)
            VStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(Color.blue.opacity(0.85))
                                .frame(width: 3, height: 6)
                        }
                    }
                }
            }
        }
    }

    private var nozzleSheet: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                .frame(width: 30, height: 34)
            VStack(spacing: 3) {
                ForEach(Array([Color.cyan, .pink, .yellow, .primary].enumerated()), id: \.offset) { _, color in
                    Capsule()
                        .fill(color.opacity(0.9))
                        .frame(width: 20, height: 4)
                }
            }
        }
    }

    private var inkTanks: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array([Color.cyan, .pink, .yellow].enumerated()), id: \.offset) { _, color in
                VStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.blue)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.85))
                        .frame(width: 8, height: 16)
                }
            }
        }
    }

    private var inkAlerts: some View {
        HStack(spacing: 3) {
            ForEach(Array([Color.primary, .cyan, .pink, .yellow].enumerated()), id: \.offset) { index, color in
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                    if index == 0 || index == 3 {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(.black)
                            .padding(2)
                            .background(Color.yellow, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
    }

    private var rollerGlyph: some View {
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 34, height: 12)
            Capsule()
                .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                .frame(width: 34, height: 12)
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.yellow)
                .offset(y: -14)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ActionRow(action: .cleaning) {}
        ActionRow(action: .deepCleaning) {}
        ActionRow(action: .quietSettings) {}
    }
    .padding()
    .frame(width: 360)
}
