import AppKit
import ObjectiveC
import SwiftUI

// MARK: - Content

struct ContentView: View {
  @ObservedObject private var model = ContentModel.shared

  @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
  @AppStorage("editorFontSize") private var editorFontSize: Double = 14
  @AppStorage("editorFontWeight") private var editorFontWeightRaw: Double = NSFont.Weight.regular.rawValue
  @AppStorage("isAlwaysOnTop") private var isAlwaysOnTop: Bool = false
  @AppStorage("isSpellCheckEnabled") private var isSpellCheckEnabled: Bool = true
  @AppStorage("isAutoCloseEnabled") private var isAutoCloseEnabled: Bool = true
  @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false

  @State private var scrollDelta: CGFloat = 0

  private var dynamicFadeHeight: CGFloat {
    let base: CGFloat = 36
    let boost = min(max(0, scrollDelta) * 0.3, 16)
    return base + boost
  }

  private var editorFontWeight: NSFont.Weight { NSFont.Weight(rawValue: editorFontWeightRaw) }

  private var nsEditorFont: NSFont {
    switch editorFontName {
    case "System":
      return NSFont.systemFont(ofSize: CGFloat(editorFontSize), weight: editorFontWeight)
    case "SystemMono":
      return NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: editorFontWeight)
    default:
      let descriptor: NSFontDescriptor = {
        let base = NSFontDescriptor(fontAttributes: [.family: editorFontName])
        let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: editorFontWeightRaw]
        return base.addingAttributes([.traits: traits])
      }()
      return NSFont(descriptor: descriptor, size: CGFloat(editorFontSize))
        ?? NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: editorFontWeight)
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
      .mask(alignment: .top) {
        VStack(spacing: 0) {
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: .clear, location: 0),
              .init(color: .white, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: dynamicFadeHeight)

          Color.white
        }
      }
    }
    .frame(minWidth: 400, minHeight: 300)
    .modifier(WindowConfigurator(isAlwaysOnTop: isAlwaysOnTop))
    .onReceive(
      NotificationCenter.default.publisher(
        for: ScrapTextEditor.Coordinator.scrollOffsetNotification)
    ) { notification in
      if let offset = notification.userInfo?["offset"] as? CGFloat {
        scrollDelta = offset
      }
    }
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
