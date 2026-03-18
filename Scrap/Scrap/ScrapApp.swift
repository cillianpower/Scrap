import SwiftUI

@main
struct Scrap: App {
  @ObservedObject var model = ContentModel.shared
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 800, height: 450)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandMenu("Format") {
        Button("Paste and Normalize") {
          NotificationCenter.default.post(
            name: ScrapTextEditor.pasteAndNormalizeNotification, object: nil)
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])

        Divider()

        Button("Toggle Dash List") {
          NotificationCenter.default.post(
            name: ScrapTextEditor.toggleDashListNotification, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command])

        Button("Toggle Numbered List") {
          NotificationCenter.default.post(
            name: ScrapTextEditor.toggleNumberedListNotification, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        Button("Toggle Comment") {
          NotificationCenter.default.post(
            name: ScrapTextEditor.toggleCommentNotification, object: nil)
        }
        .keyboardShortcut("/", modifiers: [.command])
      }

      CommandMenu("History") {
        if model.history.isEmpty {
          Text("No History")
            .disabled(true)
        } else {
          ForEach(Array(model.history.prefix(5).enumerated()), id: \.offset) { index, snapshot in
            Button {
              model.restore(snapshot)
            } label: {
              Text(snapshot.prefix(50) + (snapshot.count > 50 ? "..." : ""))
            }
          }

          Divider()

          Button("Clear History") {
            model.history.removeAll()
          }
        }
      }
    }

    Settings {
      SettingsView()
    }

    Window("Scrap Info", id: "info") {
      InfoView()
    }
    .windowResizability(.contentSize)
  }
}
