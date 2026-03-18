import SwiftUI

struct InfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Scrap")
                    .font(.headline)
                Text("Scrap is a simple and quick scratchpad for loose text, half-thoughts, and ephemeral content. By design, it does not save any content and does not write any files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcuts")
                    .font(.headline)
                
                ShortcutRow(key: "⌘ + Shift + V", description: "Paste & Normalize")
                ShortcutRow(key: "⌘ + L", description: "Toggle Dash List")
                ShortcutRow(key: "⌘ + Shift + L", description: "Toggle Numbered List")
                ShortcutRow(key: "⌘ + /", description: "Toggle Comment")
                ShortcutRow(key: "⌘ + ,", description: "Settings")
            }
            
            Divider()
            
            Text("Settings apply instantly and persist between launches. The note content remains ephemeral.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 350)
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(description)
                .font(.subheadline)
            Spacer()
            Text(key)
                .font(.system(.subheadline, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

#Preview {
    InfoView()
}
