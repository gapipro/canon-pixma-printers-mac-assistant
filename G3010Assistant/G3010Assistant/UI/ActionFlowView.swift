import SwiftUI

struct ActionFlowView: View {
    let action: AssistantAction
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .waiting
    @State private var showInkWarning = false
    @State private var showFlushConfirm = false
    @State private var didStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action.title)
                .font(.title2)
                .fontWeight(.semibold)

            switch phase {
            case .waiting:
                Text(action.subtitle)
                    .foregroundStyle(.secondary)
                Button("Cancel", role: .cancel) { dismiss() }
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
                        Button("Open Remote UI") {
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
        .frame(minWidth: 440, minHeight: 180, alignment: .topLeading)
        .interactiveDismissDisabled(phase == .running)
        .onAppear(perform: startIfNeeded)
        .alert("This uses a large amount of ink. Continue?", isPresented: $showInkWarning) {
            Button("Continue", action: continueAfterInkWarning)
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text(action.subtitle)
        }
        .alert("Run Ink Flush?", isPresented: $showFlushConfirm) {
            Button("Continue", action: run)
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Ink Flush fills the ink tubes and print head. This uses a large amount of ink.")
        }
    }

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        if action.isInkHeavy {
            Task { @MainActor in
                guard phase == .waiting else { return }
                showInkWarning = true
            }
        } else {
            run()
        }
    }

    private func continueAfterInkWarning() {
        if action == .inkFlush {
            showFlushConfirm = true
        } else {
            run()
        }
    }

    private func run() {
        phase = .running
        Task {
            do {
                try await model.perform(action)
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
        case waiting
        case running
        case succeeded
        case failed(AppError)
    }
}

#Preview {
    ActionFlowView(action: .inkFlush, model: AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
