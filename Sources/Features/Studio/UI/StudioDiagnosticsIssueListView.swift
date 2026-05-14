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
    let groups = StudioDiagnosticsIssueGrouping.groups(for: issues)

    ScrollView {
      LazyVStack(alignment: .leading, spacing: 10) {
        ForEach(groups) { group in
          StudioDiagnosticsIssueGroupRowView(
            group: group,
            onNavigateToIssue: onNavigateToIssue,
            onRevealIssueFile: onRevealIssueFile
          )
        }
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .overlay {
      if issues.isEmpty {
        emptyStateView
      }
    }
    .searchable(text: $searchText, prompt: "Search Validation")
  }

  @ViewBuilder
  private var emptyStateView: some View {
    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ContentUnavailableView(
        "Workspace Is Valid",
        systemImage: "checkmark.circle",
        description: Text("Validation found no schema or reference issues.")
      )
    } else {
      ContentUnavailableView.search
    }
  }
}

private struct StudioDiagnosticsIssueGroupRowView: View {
  let group: StudioDiagnosticsIssueGroup
  let onNavigateToIssue: (WorkspaceValidationIssue) -> Void
  let onRevealIssueFile: (WorkspaceValidationIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      headerView

      ForEach(group.issues.indices, id: \.self) { index in
        issueView(group.issues[index])
      }

      HStack(spacing: 8) {
        Button("Go to Issue") {
          onNavigateToIssue(group.navigationIssue)
        }

        Button("Reveal") {
          guard let issue = group.revealIssue else {
            return
          }

          onRevealIssueFile(issue)
        }
        .disabled(group.revealIssue == nil)

        Spacer()
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(.secondary.opacity(0.06))
    )
  }

  private var headerView: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(group.issueCountText)
        .font(.caption2)
        .fontWeight(.semibold)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.red.opacity(0.16))
        )

      Text(group.title)
        .font(.subheadline)
        .fontWeight(.semibold)

      Text(group.fieldSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func issueView(_ issue: WorkspaceValidationIssue) -> some View {
    VStack(alignment: .leading, spacing: 4) {
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

        Text(issue.field)
          .font(.caption)
          .foregroundStyle(.secondary)
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
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
