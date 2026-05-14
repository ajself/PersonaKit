import SwiftUI

struct StudioLibraryPreviewView: View {
  let selection: SidebarItem
  let state: StudioLibraryPreviewState?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let state {
        previewContent(state)
      } else {
        ContentUnavailableView(
          "Select a \(selection.singularTitle)",
          systemImage: "sidebar.leading",
          description: Text("Preview metadata and source location before opening raw content.")
        )
      }
    }
    .padding(14)
    .frame(minWidth: 300, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
    .background(.quaternary.opacity(0.06))
  }

  private func previewContent(_ state: StudioLibraryPreviewState) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("\(state.sectionTitle) Preview")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)

        Text(state.id)
          .font(.title3)
          .fontWeight(.semibold)
          .lineLimit(2)
          .textSelection(.enabled)

        if state.displayName != state.id {
          Text(state.displayName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      metadataRow(label: "Scope", value: state.scope)
      metadataRow(label: "Path", value: state.relativePath, monospaced: true)

      if let workstreamLine = state.workstreamLine {
        metadataRow(label: "Routing", value: workstreamLine)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(state.accessibilitySummary)
  }

  private func metadataRow(
    label: String,
    value: String,
    monospaced: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      Text(value)
        .font(monospaced ? .caption.monospaced() : .subheadline)
        .foregroundStyle(.primary)
        .lineLimit(4)
        .textSelection(.enabled)
    }
  }
}
