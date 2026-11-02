import ContextWorkspaceCore
import SwiftUI

struct StudioLibraryPreviewView: View {
  let selection: SidebarItem
  let state: StudioLibraryPreviewState?
  /// Items that reference the selected one; `nil` until the workspace graph has loaded.
  let users: [WorkspaceSessionMapNode]?
  /// Why "Used by" couldn't load; set only when no earlier graph is available to show.
  let usersLoadErrorMessage: String?
  let onNavigate: (StudioNavigationTarget) -> Void

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

        Text(state.displayName)
          .font(.title3)
          .fontWeight(.semibold)
          .lineLimit(2)
          .textSelection(.enabled)

        if state.displayName != state.id {
          Text(state.id)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      StudioMetadataRow(label: "Scope", value: state.scope)
      StudioMetadataRow(label: "Path", value: state.relativePath, monospaced: true)

      if let workstreamLine = state.workstreamLine {
        StudioMetadataRow(label: "Routing", value: workstreamLine)
      }

      if let skillCapabilityLine = state.skillCapabilityLine {
        StudioMetadataRow(label: "Capability", value: skillCapabilityLine)
      }

      if let skillBoundaryLine = state.skillBoundaryLine {
        StudioMetadataRow(label: "Meaning", value: skillBoundaryLine)
      }

      if let skillProviderLine = state.skillProviderLine {
        StudioMetadataRow(label: "Provided By", value: skillProviderLine)
      }

      if let skillRiskLine = state.skillRiskLine {
        StudioMetadataRow(label: "Risk", value: skillRiskLine)
      }

      if let skillReviewLine = state.skillReviewLine {
        StudioMetadataRow(label: "Human Review", value: skillReviewLine)
      }

      if let skillNotesLine = state.skillNotesLine {
        StudioMetadataRow(label: "Notes", value: skillNotesLine)
      }

      StudioInspectorSection("Used by") {
        usedByContent
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(state.accessibilitySummary)
  }

  @ViewBuilder
  private var usedByContent: some View {
    if let users {
      if users.isEmpty {
        usedByNote("Not used by any session or library item.")
      } else {
        ForEach(users, id: \.key) { node in
          usedByRow(node)
        }
      }
    } else if let usersLoadErrorMessage {
      usedByLoadFailure(reason: usersLoadErrorMessage)
    } else {
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.small)

        usedByNote("Finding references…")
      }
    }
  }

  @ViewBuilder
  private func usedByRow(_ node: WorkspaceSessionMapNode) -> some View {
    if let target = SessionsMapNavigationResolver.navigationTarget(
      for: node,
      selectedSessionID: nil
    ) {
      let kindTitle = target.sidebarItem.singularTitle

      Button {
        onNavigate(target)
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 1) {
            Text(node.displayName)
              .lineLimit(1)
              .truncationMode(.middle)

            Text(StudioLibraryUsageState.rowSubtitle(for: node, kindTitle: kindTitle))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        } icon: {
          Image(systemName: target.sidebarItem.systemImage)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(StudioLibraryUsageState.rowAccessibilityLabel(for: node, kindTitle: kindTitle))
      .help("Open \(kindTitle) \(node.displayName)")
    }
  }

  // The graph reloads after every successful workspace reload, so saving a fix clears this.
  private func usedByLoadFailure(reason: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      usedByNote("References couldn't be loaded.")

      Text(reason)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)

      usedByNote("If Validation Results shows a problem, fix it and save. References reload when the workspace does.")

      Button("Show Validation Results") {
        onNavigate(StudioNavigationTarget(sidebarItem: .validationResults, searchText: ""))
      }
      .controlSize(.small)
    }
  }

  private func usedByNote(_ text: String) -> some View {
    Text(text)
      .font(.callout)
      .foregroundStyle(.secondary)
  }
}
