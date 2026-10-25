import SwiftUI

@main
struct G3010AssistantApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("G3010 Assistant") {
            MainView()
                .environmentObject(model)
        }
        .defaultSize(width: 720, height: 560)
    }
}
