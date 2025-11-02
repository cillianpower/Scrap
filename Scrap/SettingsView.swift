import SwiftUI

struct SettingsView: View {
    @AppStorage("editorFontName") private var editorFontName: String = "SystemMono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    var body: some View {
        Form {
            Section("Editor") {
                HStack {
                    Text("Font")
                    Spacer()
                    Picker("Font", selection: $editorFontName) {
                        Text("System").tag("System")
                        Text("System Monospaced").tag("SystemMono")
                    }
                    .labelsHidden()
                }
                HStack {
                    Text("Size")
                    Spacer()
                    Slider(value: $editorFontSize, in: 10...36, step: 1)
                        .frame(maxWidth: 220)
                    Text("\(Int(editorFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
            Text("Settings apply instantly and persist between launches. The note content remains ephemeral.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 420)
    }
}

#Preview("Settings") {
    SettingsView()
        .frame(width: 420)
}
