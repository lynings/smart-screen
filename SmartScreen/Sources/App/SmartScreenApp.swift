import SwiftUI

@main
struct SmartScreenApp: App {
    var body: some Scene {
        WindowGroup {
            RecordingView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 500)
    }
}
