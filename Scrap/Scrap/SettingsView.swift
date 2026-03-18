import AppKit
import SwiftUI

struct SettingsView: View {
  @Environment(\.openWindow) private var openWindow

  @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
  @AppStorage("editorFontSize") private var editorFontSize: Double = 14
  @AppStorage("isAlwaysOnTop") private var isAlwaysOnTop: Bool = false
  @AppStorage("isSpellCheckEnabled") private var isSpellCheckEnabled: Bool = false
  @AppStorage("isAutoCloseEnabled") private var isAutoCloseEnabled: Bool = true
  @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false

  @State private var fontSearchQuery: String = ""

  private let allFonts: [String] = NSFontManager.shared.availableFontFamilies.sorted()

  // Layout Constants
  private let labelWidth: CGFloat = 70
  private let inputHeight: CGFloat = 20

  private var filteredFonts: [String] {
    if fontSearchQuery.isEmpty {
      return allFonts
    } else {
      return allFonts.filter { $0.localizedCaseInsensitiveContains(fontSearchQuery) }
    }
  }

  var body: some View {
    mainSettingsView
      .frame(width: 350, height: 280)
  }

  private var mainSettingsView: some View {
    VStack(alignment: .leading, spacing: 10) {

      // MARK: Typography
      VStack(spacing: 8) {

        // Font Size (Power Slider)
        HStack(spacing: 12) {
          inspectorLabel("Size")

          HStack(spacing: 8) {
            Slider(value: $editorFontSize, in: 10...32, step: 1)
              .controlSize(.small)

            TextField("", value: $editorFontSize, formatter: NumberFormatter())
              .textFieldStyle(.plain)
              .font(.subheadline)
              .multilineTextAlignment(.center)
              .frame(width: 36)
              .padding(.vertical, 3)
              .background(
                RoundedRectangle(cornerRadius: 5)
                  .fill(Color(nsColor: .controlBackgroundColor))
                  .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
              )
          }
        }

        // Font Family (Integrated Stack)
        HStack(alignment: .top, spacing: 12) {
          inspectorLabel("Font")
            .padding(.top, 4)

          VStack(spacing: 0) {
            TextField("Search fonts...", text: $fontSearchQuery)
              .textFieldStyle(.plain)
              .controlSize(.small)
              .font(.subheadline)
              .padding(6)
              .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Picker("", selection: $editorFontName) {
              Text("System Default").tag("System")
              Text("System Monospaced").tag("SystemMono")
              if !filteredFonts.isEmpty {
                Divider()
                ForEach(filteredFonts, id: \.self) { font in
                  Text(font).tag(font)
                }
              }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor))
          }
          .background(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
      }

      Divider()
        .padding(.vertical, 2)

      // MARK: Behavior
      VStack(spacing: 6) {
        inspectorToggle("Float", isOn: $isAlwaysOnTop, description: "Keep window on top")
        inspectorToggle("Spell Check", isOn: $isSpellCheckEnabled)
        inspectorToggle("Auto-Close", isOn: $isAutoCloseEnabled, description: "Brackets & quotes")
        inspectorToggle("Line Numbers", isOn: $showLineNumbers)
      }

      Divider()
        .padding(.vertical, 2)

      // MARK: Footer
      HStack {
        Button {
          openWindow(id: "info")
        } label: {
          Image(systemName: "info.circle")
            .font(.body)
        }
        .buttonStyle(.plain)
        .help("Show Shortcuts & Info")

        Spacer()

        Button("Reset") {
          resetDefaults()
        }
        .controlSize(.small)
        .buttonStyle(.link)
        .font(.footnote)
      }
    }
    .padding(16)
  }

  private func inspectorLabel(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(width: labelWidth, alignment: .trailing)
  }

  private func inspectorToggle(_ title: String, isOn: Binding<Bool>, description: String? = nil)
    -> some View
  {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Color.clear.frame(width: labelWidth, height: 1)  // Alignment shim

      Toggle(isOn: isOn) {
        HStack(spacing: 4) {
          Text(title)
            .font(.subheadline)
          if let description = description {
            Text("(\(description))")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }
      }
      .toggleStyle(.checkbox)

      Spacer()
    }
  }

  private func resetDefaults() {
    withAnimation {
      editorFontName = "SystemMono"
      editorFontSize = 14
      isAlwaysOnTop = false
      isSpellCheckEnabled = true
      isAutoCloseEnabled = true
      showLineNumbers = false
      fontSearchQuery = ""
    }
  }
}

#Preview("Settings") {
  SettingsView()
}
