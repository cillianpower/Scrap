
import SwiftUI

@main
struct Scrap: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 700, height: 500)
        .windowStyle(.titleBar)
        Settings {
            SettingsView()
        }
    }
}

