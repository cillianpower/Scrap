import AppKit
import ObjectiveC
import SwiftUI

// MARK: - Content

struct ContentView: View {
  @ObservedObject private var model = ContentModel.shared

  @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
  @AppStorage("editorFontSize") private var editorFontSize: Double = 14
  @AppStorage("isAlwaysOnTop") private var isAlwaysOnTop: Bool = false
  @AppStorage("isSpellCheckEnabled") private var isSpellCheckEnabled: Bool = true
  @AppStorage("isAutoCloseEnabled") private var isAutoCloseEnabled: Bool = true
  @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false

  private var nsEditorFont: NSFont {
    switch editorFontName {
    case "System":
      return NSFont.systemFont(ofSize: CGFloat(editorFontSize))
    case "SystemMono":
      return NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: .regular)
    default:
      return NSFont(name: editorFontName, size: CGFloat(editorFontSize))
        ?? NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: .regular)
    }
  }

  var body: some View {
    ZStack {
      VisualEffectView(material: .hudWindow, blending: .behindWindow, state: .active)
        .ignoresSafeArea()

      ScrapTextEditor(
        text: $model.text,
        font: nsEditorFont,
        isSpellCheckEnabled: isSpellCheckEnabled,
        isAutoCloseEnabled: isAutoCloseEnabled,
        showLineNumbers: showLineNumbers
      )
      .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
    }
    .frame(minWidth: 400, minHeight: 300)
    .modifier(WindowConfigurator(isAlwaysOnTop: isAlwaysOnTop))
  }
}

// MARK: - Window setup

struct WindowConfigurator: ViewModifier {
  var isAlwaysOnTop: Bool

  func body(content: Content) -> some View {
    content.background(
      WindowAccessor { window in
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear

        // Set window level based on pin setting
        window.level = isAlwaysOnTop ? .floating : .normal
      })
  }
}

private struct WindowAccessor: NSViewRepresentable {
  var configure: (NSWindow?) -> Void
  func makeNSView(context: Context) -> NSView {
    let v = NSView()
    DispatchQueue.main.async { configure(v.window) }
    return v
  }
  func updateNSView(_ v: NSView, context: Context) {
    DispatchQueue.main.async { configure(v.window) }
  }
}

// MARK: - Visual effect (blur)

struct VisualEffectView: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .hudWindow
  var blending: NSVisualEffectView.BlendingMode = .behindWindow
  var state: NSVisualEffectView.State = .active

  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = material
    v.blendingMode = blending
    v.state = state
    v.isEmphasized = true
    return v
  }

  func updateNSView(_ v: NSVisualEffectView, context: Context) {
    v.material = material
    v.blendingMode = blending
    v.state = state
  }
}
