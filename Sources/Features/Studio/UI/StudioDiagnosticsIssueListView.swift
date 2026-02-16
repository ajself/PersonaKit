import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Diagnostics issue list with navigation and reveal actions.
struct StudioDiagnosticsIssueListView: View {
  let issues: [WorkspaceValidationIssue]
  @Binding var searchText: String
  let onNavigateToIssue: (WorkspaceValidationIssue) -> Void
  let onRevealIssueFile: (WorkspaceValidationIssue) -> Void

  var body: some View {
    List(issues.indices, id: \.self) { index in
      let issue = issues[index]

      HStack(alignment: .top, spacing: 12) {
        Button {
          onNavigateToIssue(issue)
        } label: {
          StudioDiagnosticsIssueRowView(issue: issue)
        }
        .buttonStyle(.plain)

        Button("Reveal") {
          onRevealIssueFile(issue)
        }
        .disabled(issue.filePath == nil)
        .buttonStyle(.borderless)
      }
    }
    .overlay {
      if issues.isEmpty {
        ContentUnavailableView(
          "No Issues",
          systemImage: "checkmark.circle",
          description: Text("Workspace validation is clean.")
        )
      }
    }
    .searchable(text: $searchText, prompt: "Search Validation")
  }
}

private struct StudioDiagnosticsIssueRowView: View {
  let issue: WorkspaceValidationIssue

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(issue.severity.rawValue.capitalized)
          .font(.caption2)
          .fontWeight(.semibold)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(.red.opacity(0.16))
          )

        Text(issue.entityType.rawValue.capitalized)
          .font(.caption)
          .foregroundStyle(.secondary)

        if let entityId = issue.entityId {
          Text(entityId)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Text(issue.message)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)

      if let filePath = issue.filePath {
        Text(filePath)
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}
