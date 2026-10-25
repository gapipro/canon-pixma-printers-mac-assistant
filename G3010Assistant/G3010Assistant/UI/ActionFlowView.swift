import SwiftUI

struct ActionFlowView: View {
    let action: AssistantAction
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var options = ActionOptions()
    @State private var phase: Phase = .configure
    @State private var showInkWarning = false
    @State private var showSecondConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action.title)
                .font(.title2)
                .fontWeight(.semibold)

            switch phase {
            case .configure:
                ScrollView {
                    ActionOptionsForm(action: action, options: $options)
                }
                HStack {
                    Button("Cancel", role: .cancel) { dismiss() }
                    Spacer()
                    Button(executeTitle) {
                        requestExecute()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            case .running:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Running \(action.title)…")
                }
            case .succeeded:
                Text("\(action.title) finished.")
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            case .failed(let error):
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    if case .endpointMissing = error {
                        Button("Open Remote UI in Safari") {
                            model.openRemoteUI()
                        }
                    }
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 260, alignment: .topLeading)
        .interactiveDismissDisabled(phase == .running)
        .alert("This uses a large amount of ink. Continue?", isPresented: $showInkWarning) {
            Button("Continue", action: continueAfterInkWarning)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(action.subtitle)
        }
        .alert("Run \(action.title)?", isPresented: $showSecondConfirm) {
            Button("Continue", action: run)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(secondConfirmMessage)
        }
    }

    private var executeTitle: String {
        switch action {
        case .quietSettings, .autoPower, .customSettings, .inkNotificationSettings:
            return "Apply"
        default:
            return "Execute"
        }
    }

    private func requestExecute() {
        if action.isInkHeavy {
            showInkWarning = true
        } else {
            run()
        }
    }

    private func continueAfterInkWarning() {
        switch action {
        case .deepCleaning, .inkFlush:
            showSecondConfirm = true
        default:
            run()
        }
    }

    private var secondConfirmMessage: String {
        switch action {
        case .inkFlush:
            return "Ink Flush fills the ink tubes and print head. This uses a large amount of ink."
        case .deepCleaning:
            return "Deep Cleaning uses a large amount of ink to unclog nozzles."
        default:
            return action.subtitle
        }
    }

    private func run() {
        phase = .running
        Task {
            do {
                try await model.perform(action, options: options)
                phase = .succeeded
            } catch let error as AppError {
                if error == .authFailed {
                    dismiss()
                    return
                }
                phase = .failed(error)
            } catch {
                phase = .failed(.parse(error.localizedDescription))
            }
        }
    }

    private enum Phase: Equatable {
        case configure
        case running
        case succeeded
        case failed(AppError)
    }
}

#Preview {
    ActionFlowView(action: .quietSettings, model: AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
