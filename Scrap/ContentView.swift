import SwiftUI
import AppKit
import ObjectiveC

// MARK: - Content

struct ContentView: View {
    @State private var text = ""

    @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    private var editorFont: Font {
        switch editorFontName {
        case "System":
            return .system(size: CGFloat(editorFontSize))
        case "SystemMono":
            return .system(size: CGFloat(editorFontSize), design: .monospaced)
        default:
            // Fallback to System Mono if an unknown value is present
            return .system(size: CGFloat(editorFontSize), design: .monospaced)
        }
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blending: .behindWindow, state: .active)

            TextEditor(text: $text)
                .font(editorFont)
                .scrollContentBackground(.hidden) // hide default NSTextView background
                .padding()
                .frame(minWidth: 400, minHeight: 300)
        }
        .modifier(WindowConfigurator()) // make the NSWindow transparent
    }
}

// MARK: - Window setup

struct WindowConfigurator: ViewModifier {
    func body(content: Content) -> some View {
        content.background(WindowAccessor { window in
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.toolbar = nil
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
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
