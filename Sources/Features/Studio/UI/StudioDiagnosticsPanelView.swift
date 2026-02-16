import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Diagnostics panel with validation issue search and navigation helpers.
struct StudioDiagnosticsPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var selection: SidebarItem?
  @Binding var selectedLibraryItemID: String?
  @Binding var searchText: String

  var body: some View {
    let issues = filteredValidationIssues(workspaceStore.validation.issues)

    VStack(alignment: .leading, spacing: 12) {
      StudioDiagnosticsHeaderView(
        summary: workspaceStore.validation.summary,
        onValidateWorkspace: {
          workspaceStore.validateWorkspace()
        }
      )

      if let validationErrorMessage = workspaceStore.validationErrorMessage {
        ContentUnavailableView(
          "Validation Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(validationErrorMessage)
        )
      } else {
        StudioDiagnosticsIssueListView(
          issues: issues,
          searchText: $searchText,
          onNavigateToIssue: { issue in
            let navigationTarget = diagnosticsNavigationTarget(for: issue)
            selection = navigationTarget.sidebarItem
            selectedLibraryItemID = navigationTarget.selectedLibraryItemID
            searchText = navigationTarget.searchText
          },
          onRevealIssueFile: { issue in
            guard let filePath = issue.filePath else {
              return
            }

            workspaceStore.revealValidationIssueInFinder(filePath: filePath)
          }
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
  }

  private func filteredValidationIssues(
    _ issues: [WorkspaceValidationIssue]
  ) -> [WorkspaceValidationIssue] {
    let normalizedSearch = normalizedSearchText

    guard !normalizedSearch.isEmpty else {
      return issues
    }

    return issues.filter { issue in
      issue.message.localizedCaseInsensitiveContains(normalizedSearch)
        || issue.entityType.rawValue.localizedCaseInsensitiveContains(normalizedSearch)
        || (issue.entityId?.localizedCaseInsensitiveContains(normalizedSearch) ?? false)
        || (issue.filePath?.localizedCaseInsensitiveContains(normalizedSearch) ?? false)
    }
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func sidebarItem(for entityType: WorkspaceValidationEntityType) -> SidebarItem {
    switch entityType {
    case .session:
      return .sessions
    case .persona:
      return .personas
    case .kit:
      return .kits
    case .directive:
      return .directives
    case .intent:
      return .intents
    case .skill:
      return .skills
    case .essentials:
      return .essentials
    }
  }

  private func diagnosticsNavigationTarget(
    for issue: WorkspaceValidationIssue
  ) -> DiagnosticsNavigationTarget {
    let sidebarItem = sidebarItem(for: issue.entityType)
    let selectedLibraryItemID = issue.entityId ?? inferredEntityID(for: issue)

    if let selectedLibraryItemID {
      return DiagnosticsNavigationTarget(
        sidebarItem: sidebarItem,
        selectedLibraryItemID: selectedLibraryItemID,
        searchText: selectedLibraryItemID
      )
    }

    if let filePath = issue.filePath {
      return DiagnosticsNavigationTarget(
        sidebarItem: sidebarItem,
        selectedLibraryItemID: nil,
        searchText: filePath
      )
    }

    return DiagnosticsNavigationTarget(
      sidebarItem: sidebarItem,
      selectedLibraryItemID: nil,
      searchText: issue.message
    )
  }

  private func inferredEntityID(for issue: WorkspaceValidationIssue) -> String? {
    guard let filePath = issue.filePath else {
      return nil
    }

    let lastPathComponent = URL(fileURLWithPath: filePath).lastPathComponent

    switch issue.entityType {
    case .session:
      return removingSuffix(".session.json", from: lastPathComponent)
    case .persona:
      return removingSuffix(".persona.json", from: lastPathComponent)
    case .kit:
      return removingSuffix(".kit.json", from: lastPathComponent)
    case .directive:
      return removingSuffix(".directive.json", from: lastPathComponent)
    case .intent:
      return removingSuffix(".intent.json", from: lastPathComponent)
    case .skill:
      return removingSuffix(".skill.json", from: lastPathComponent)
    case .essentials:
      return removingSuffix(".md", from: lastPathComponent)
    }
  }

  private func removingSuffix(_ suffix: String, from value: String) -> String? {
    guard value.hasSuffix(suffix) else {
      return nil
    }

    return String(value.dropLast(suffix.count))
  }
}

private struct DiagnosticsNavigationTarget {
  let sidebarItem: SidebarItem
  let selectedLibraryItemID: String?
  let searchText: String
}
