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
          systemImage: "sidebar.trailing",
          description: Text("Preview metadata and source location before opening raw content.")
        )
        .frame(maxWidth: .infinity, minHeight: 220)
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
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

      if let skillCapabilityLine = state.skillCapabilityLine {
        metadataRow(label: "Capability", value: skillCapabilityLine)
      }

      if let skillBoundaryLine = state.skillBoundaryLine {
        metadataRow(label: "Meaning", value: skillBoundaryLine)
      }

      if let skillProviderLine = state.skillProviderLine {
        metadataRow(label: "Provided By", value: skillProviderLine)
      }

      if let skillRiskLine = state.skillRiskLine {
        metadataRow(label: "Risk", value: skillRiskLine)
      }

      if let skillReviewLine = state.skillReviewLine {
        metadataRow(label: "Human Review", value: skillReviewLine)
      }

      if let skillNotesLine = state.skillNotesLine {
        metadataRow(label: "Notes", value: skillNotesLine)
      }
    }
    .accessibilityElement(children: .contain)
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
        .lineLimit(monospaced ? 3 : 4)
        .truncationMode(monospaced ? .middle : .tail)
        .textSelection(.enabled)
    }
  }
}
