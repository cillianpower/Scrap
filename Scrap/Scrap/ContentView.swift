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
  @AppStorage("windowMaterial") private var windowMaterial: String = "frosted"
  @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 1.0

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
      Group {
        switch windowMaterial {
        case "glass":
          if #available(macOS 26.0, *) {
            GlassEffectView(style: .regular, tintOpacity: backgroundOpacity)
          } else {
            // macOS 15 fallback: no NSVisualEffectView — just transparency
            // with tint overlay. Window-level blur is set via the private
            // CGSSetWindowBackgroundBlurRadius in WindowConfigurator.
            Color.clear
              .overlay(
                Color(nsColor: .windowBackgroundColor)
                  .opacity(backgroundOpacity)
              )
          }
        case "opaque":
          Color(nsColor: .windowBackgroundColor)
        default:
          VisualEffectView(material: .hudWindow, blending: .behindWindow, state: .active)
        }
      }
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
    .modifier(WindowConfigurator(isAlwaysOnTop: isAlwaysOnTop, windowMaterial: windowMaterial))
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
  var windowMaterial: String

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

        // Window material properties
        switch windowMaterial {
        case "opaque":
          window.isOpaque = true
          window.backgroundColor = .windowBackgroundColor
        default:
          window.isOpaque = false
          // Ghostty uses near-transparent white — not .clear — to get a
          // look that matches Terminal.app and allows window-server blur.
          window.backgroundColor = NSColor.white.withAlphaComponent(0.001)
        }

        // Ghostty uses CGSSetWindowBackgroundBlurRadius with sentinel -1
        // for macos-glass-regular. On macOS 26+ the NSGlassEffectView handles
        // this; on pre-26 we call the private API directly.
        if windowMaterial == "glass" {
          if #available(macOS 26.0, *) {
            // GlassEffectView handles the blur, nothing extra needed
          } else {
            WindowBlur.applyGlassBlur(to: window)
          }
        }

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

// MARK: - Window blur (private CGS API)

/// Matches Ghostty's use of CGSSetWindowBackgroundBlurRadius with sentinel
/// values for glass effects. This is a private CoreGraphics API shared by
/// Terminal.app, iTerm2, Ghostty, and most other macOS terminal emulators.
private enum WindowBlur {
  /// Applies the macos-glass-regular blur to a window.
  static func applyGlassBlur(to window: NSWindow) {
    let radius: Int32 = -1  // Sentinal for macos-glass-regular
    setWindowBackgroundBlur(window: window, radius: radius)
  }

  private static let setBlur: (@convention(c) (Int, Int, Int32) -> Int32)? = {
    let handle = dlopen(nil, RTLD_NOLOAD)
    guard let sym = dlsym(handle, "CGSSetWindowBackgroundBlurRadius") else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) (Int, Int, Int32) -> Int32).self)
  }()

  private static let defaultConnection: (@convention(c) () -> Int)? = {
    let handle = dlopen(nil, RTLD_NOLOAD)
    guard let sym = dlsym(handle, "CGSDefaultConnectionForThread") else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) () -> Int).self)
  }()

  private static func setWindowBackgroundBlur(window: NSWindow, radius: Int32) {
    guard let setBlur, let defaultConnection else { return }
    let conn = defaultConnection()
    let winNum = window.windowNumber
    _ = setBlur(conn, winNum, radius)
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

// MARK: - Glass effect (macOS 26+)

@available(macOS 26.0, *)
private class GlassNSView: NSView {
  private let glassView = NSGlassEffectView()

  init(style: NSGlassEffectView.Style, tintOpacity: Double) {
    super.init(frame: .zero)
    glassView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(glassView)
    NSLayoutConstraint.activate([
      glassView.topAnchor.constraint(equalTo: topAnchor),
      glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
      glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
      glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
    glassView.style = style
    glassView.cornerRadius = 16
    update(tintOpacity: tintOpacity)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func update(tintOpacity: Double) {
    glassView.tintColor = NSColor.controlBackgroundColor.withAlphaComponent(tintOpacity)
  }
}

@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
  var style: NSGlassEffectView.Style = .regular
  var tintOpacity: Double = 0.85

  func makeNSView(context: Context) -> NSView {
    return GlassNSView(style: style, tintOpacity: tintOpacity)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let glass = nsView as? GlassNSView else { return }
    glass.update(tintOpacity: tintOpacity)
  }
}
