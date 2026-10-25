import SwiftUI

struct SelectPrinterSheet: View {
    @ObservedObject var model: AppModel
    @State private var manualIP = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Printer")
                .font(.title2)
                .fontWeight(.semibold)

            if model.printers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Looking for a Canon G3010 on the local network.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.printers) { printer in
                    Button {
                        model.select(printer)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(printer.name)
                            Text("\(printer.model) · \(printer.host)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("IP address", text: $manualIP)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addManual)
                Button("Add", action: addManual)
                    .disabled(manualIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Spacer()
                Button("Close") {
                    model.isSelectingPrinter = false
                }
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 360)
        .onAppear { model.startBrowsing() }
    }

    private func addManual() {
        model.addManualPrinter(ip: manualIP)
        manualIP = ""
    }
}

#Preview {
    SelectPrinterSheet(model: AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
