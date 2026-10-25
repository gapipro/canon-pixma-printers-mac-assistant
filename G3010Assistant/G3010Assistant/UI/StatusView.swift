import SwiftUI

struct StatusView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Printer status")
                .font(.title2)
                .fontWeight(.semibold)
            if let printer = model.selectedPrinter {
                Text(printer.displayName)
                    .foregroundStyle(.secondary)
            }

            if model.isLoadingStatus {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking printer…")
                }
            } else if let status = model.printerStatus {
                Text(status.isIdle ? "Idle" : "Busy")
                    .font(.headline)
                Text(status.detail)
                if let modelName = status.model, !modelName.isEmpty {
                    Text("Model: \(modelName)")
                }
            } else if let statusError = model.statusError {
                Text(statusError)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Refresh") {
                    Task { await model.refreshStatus() }
                }
                .disabled(model.selectedPrinter == nil || model.isLoadingStatus)
                Spacer()
                Button("Close") {
                    model.isShowingStatus = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 220)
        .task { await model.refreshStatus() }
    }
}

#Preview {
    StatusView(model: AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
