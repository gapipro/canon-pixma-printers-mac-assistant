import SwiftUI

struct PasswordPrompt: View {
    @ObservedObject var model: AppModel
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Printer Password")
                .font(.title2)
                .fontWeight(.semibold)
            Text(prompt)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            if let passwordError = model.passwordError {
                Text(passwordError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    model.isPromptingPassword = false
                }
                Button("Save", action: save)
                    .disabled(password.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var prompt: String {
        let name = model.selectedPrinter?.displayName ?? "this printer"
        return "The factory serial password did not work for \(name). Enter the custom Remote UI admin password. It is saved in Keychain for this printer only."
    }

    private func save() {
        model.savePassword(password)
    }
}

#Preview {
    PasswordPrompt(model: AppModel(previewPrinters: PreviewPrinterBrowser.samplePrinters))
}
