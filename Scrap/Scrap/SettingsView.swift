import AppKit
import SwiftUI

struct SettingsView: View {
  @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
  @AppStorage("editorFontSize") private var editorFontSize: Double = 14
  @AppStorage("editorFontWeight") private var editorFontWeightRaw: Double = NSFont.Weight.regular.rawValue
  @AppStorage("isAlwaysOnTop") private var isAlwaysOnTop: Bool = false
  @AppStorage("isSpellCheckEnabled") private var isSpellCheckEnabled: Bool = false
  @AppStorage("isAutoCloseEnabled") private var isAutoCloseEnabled: Bool = true
  @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false
  @AppStorage("windowMaterial") private var windowMaterial: String = "frosted"
  @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 1.0

  @State private var fontSearchQuery: String = ""

  private let allFonts: [String] = NSFontManager.shared.availableFontFamilies.sorted()

  private let fontWeights: [(String, Double)] = [
    ("Ultra Light", NSFont.Weight.ultraLight.rawValue),
    ("Thin", NSFont.Weight.thin.rawValue),
    ("Light", NSFont.Weight.light.rawValue),
    ("Regular", NSFont.Weight.regular.rawValue),
    ("Medium", NSFont.Weight.medium.rawValue),
    ("Semibold", NSFont.Weight.semibold.rawValue),
    ("Bold", NSFont.Weight.bold.rawValue),
    ("Heavy", NSFont.Weight.heavy.rawValue),
    ("Black", NSFont.Weight.black.rawValue),
  ]

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
      .frame(width: 350, height: 460)
  }

  private var mainSettingsView: some View {
    VStack(alignment: .leading, spacing: 10) {

      // MARK: Typography
      VStack(alignment: .leading, spacing: 8) {
        Text("Typography")
          .font(.subheadline)
          .foregroundStyle(.secondary)

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

        // Font Weight
        HStack(spacing: 12) {
          inspectorLabel("Weight")

          Picker("", selection: $editorFontWeightRaw) {
            ForEach(fontWeights, id: \.1) { name, raw in
              Text(name).tag(raw)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .controlSize(.small)
          .frame(maxWidth: .infinity, alignment: .leading)
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

      // MARK: General
      VStack(alignment: .leading, spacing: 6) {
        Text("General")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        inspectorToggle("Float", isOn: $isAlwaysOnTop, description: "Keep window on top")
        inspectorToggle("Spell Check", isOn: $isSpellCheckEnabled)
        inspectorToggle("Auto-Close", isOn: $isAutoCloseEnabled, description: "Brackets & quotes")
        inspectorToggle("Line Numbers", isOn: $showLineNumbers)
      }

      Divider()
        .padding(.vertical, 2)

      // MARK: Window Material
      VStack(alignment: .leading, spacing: 8) {
        Text("Window Material")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Picker("", selection: $windowMaterial) {
          Text("Frosted (blur)").tag("frosted")
          Text("Glass").tag("glass")
          Text("Opaque").tag("opaque")
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()

        if windowMaterial == "glass" {
          HStack {
            Text("Opacity")
              .font(.caption)
              .foregroundStyle(.tertiary)
            Slider(value: $backgroundOpacity, in: 0...1, step: 0.05)
            Text("\(Int(backgroundOpacity * 100))%")
              .font(.caption)
              .foregroundStyle(.tertiary)
              .frame(width: 32, alignment: .trailing)
          }
        }
      }

      Divider()
        .padding(.vertical, 2)

      // MARK: Footer
      HStack {
        Text("Settings apply instantly and persist between launches.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

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
      editorFontWeightRaw = NSFont.Weight.regular.rawValue
      isAlwaysOnTop = false
      isSpellCheckEnabled = true
      isAutoCloseEnabled = true
      showLineNumbers = false
      windowMaterial = "frosted"
      backgroundOpacity = 1.0
      fontSearchQuery = ""
    }
  }
}

#Preview("Settings") {
  SettingsView()
}
