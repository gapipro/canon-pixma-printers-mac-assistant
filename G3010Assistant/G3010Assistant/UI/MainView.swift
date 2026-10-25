import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Printer: \(model.selectedPrinter?.name ?? "Not selected")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let host = model.selectedPrinter?.host {
                        Text(host)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Select Printer") {
                    model.isSelectingPrinter = true
                }
            }

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(Self.gridActions) { action in
                        ActionRow(action: action) {
                            model.begin(action)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("View printer status") {
                    model.isShowingStatus = true
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $model.isSelectingPrinter) {
            SelectPrinterSheet(model: model)
        }
        .sheet(isPresented: $model.isPromptingPassword) {
            PasswordPrompt(model: model)
        }
        .sheet(item: $model.activeAction, onDismiss: model.promptForRejectedPasswordIfNeeded) { action in
            ActionFlowView(action: action, model: model)
        }
        .sheet(isPresented: $model.isShowingStatus) {
            StatusView(model: model)
        }
        .onAppear { model.startBrowsing() }
    }

    /// Row-major order: column one is `leftColumn`, column two is `rightColumn`.
    static var gridActions: [AssistantAction] {
        let left = AssistantAction.leftColumn
        let right = AssistantAction.rightColumn
        let count = min(left.count, right.count)
        var actions: [AssistantAction] = []
        actions.reserveCapacity(left.count + right.count)
        for index in 0..<count {
            actions.append(left[index])
            actions.append(right[index])
        }
        if left.count > count {
            actions.append(contentsOf: left[count...])
        } else if right.count > count {
            actions.append(contentsOf: right[count...])
        }
        return actions
    }
}

#Preview {
    MainView()
        .environmentObject(AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
