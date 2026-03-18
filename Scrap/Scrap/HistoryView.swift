import SwiftUI

struct HistoryView: View {
  @ObservedObject var model = ContentModel.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("History")
          .font(.headline)
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 8)

      if model.history.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "clock")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
          Text("No History Yet")
            .font(.headline)
          Text("Snapshots will appear here automatically\nwhen you pause writing.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(Array(model.history.enumerated()), id: \.offset) { index, snapshot in
            HistoryItemView(snapshot: snapshot)
          }
        }
        .listStyle(.inset)
      }
    }
  }
}

struct HistoryItemView: View {
  let snapshot: String
  @ObservedObject var model = ContentModel.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(snapshot)
        .lineLimit(3)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.primary)

      HStack {
        Text("\(snapshot.count) characters")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Button("Restore") {
          model.restore(snapshot)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.vertical, 4)
  }
}
