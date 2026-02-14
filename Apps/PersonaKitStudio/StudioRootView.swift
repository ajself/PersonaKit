import PersonaKitCore
import SwiftUI

/// Root Studio split view with sidebar navigation, session editing, and diagnostics.
struct StudioRootView: View {
  let workspaceStore: WorkspaceStore
  @State private var selection: SidebarItem? = .sessions
  @State private var selectedLibraryItemID: String?
  @State private var searchText = ""

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("Sessions") {
          sidebarRow(for: .sessions)
        }
        Section("Library") {
          ForEach(SidebarItem.libraryItems, id: \.self) { item in
            sidebarRow(for: item)
          }
        }
        Section("Diagnostics") {
          sidebarRow(for: .validationResults)
        }
      }
      .navigationTitle("PersonaKit Studio")
    } detail: {
      detailView
    }
  }

  private func sidebarRow(for item: SidebarItem) -> some View {
    Label(item.title, systemImage: item.systemImage)
      .tag(item)
  }

  @ViewBuilder
  private var detailView: some View {
    if workspaceStore.workspaceURL == nil {
      ContentUnavailableView(
        "No Workspace Selected",
        systemImage: "folder.badge.questionmark",
        description: Text("Use File > Open Workspace… to load a workspace.")
      )
    } else if let loadErrorMessage = workspaceStore.loadErrorMessage {
      ContentUnavailableView(
        "Workspace Load Failed",
        systemImage: "exclamationmark.triangle",
        description: Text(loadErrorMessage)
      )
    } else {
      switch selection ?? .sessions {
      case .sessions:
        SessionsPanelView(
          workspaceStore: workspaceStore,
          searchText: $searchText
        )
      case .personas:
        libraryListView(items: filteredItems(workspaceStore.snapshot.personas))
      case .directives:
        libraryListView(items: filteredItems(workspaceStore.snapshot.directives))
      case .kits:
        libraryListView(items: filteredItems(workspaceStore.snapshot.kits))
      case .essentials:
        libraryListView(items: filteredItems(workspaceStore.snapshot.essentials))
      case .skills:
        libraryListView(items: filteredItems(workspaceStore.snapshot.skills))
      case .intents:
        libraryListView(items: filteredItems(workspaceStore.snapshot.intents))
      case .validationResults:
        diagnosticsView
      }
    }
  }

  private func libraryListView(items: [WorkspaceListItem]) -> some View {
    List(items, id: \.id, selection: $selectedLibraryItemID) { item in
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(item.id)
            .font(.headline)

          Spacer()

          scopeBadge(scope: item.sourceScope)
        }

        if item.displayName != item.id {
          Text(item.displayName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Text(item.fileURL.path())
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
          .textSelection(.enabled)
      }
      .padding(.vertical, 4)
      .tag(Optional(item.id))
    }
    .searchable(text: $searchText, prompt: "Search \(selection?.title ?? "Items")")
    .overlay {
      if items.isEmpty {
        ContentUnavailableView.search
      }
    }
  }

  private func filteredItems(_ items: [WorkspaceListItem]) -> [WorkspaceListItem] {
    let normalizedSearch = normalizedSearchText

    guard !normalizedSearch.isEmpty else {
      return items
    }

    return items.filter { item in
      item.id.localizedCaseInsensitiveContains(normalizedSearch)
        || item.displayName.localizedCaseInsensitiveContains(normalizedSearch)
        || item.fileURL.path().localizedCaseInsensitiveContains(normalizedSearch)
    }
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func scopeBadge(scope: WorkspaceSourceScope) -> some View {
    Text(scope.displayName)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(scope == .project ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
  }

  private var diagnosticsView: some View {
    let issues = filteredValidationIssues(workspaceStore.validation.issues)

    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text("Validation Results")
          .font(.title3)
          .fontWeight(.semibold)

        Spacer()

        Button("Validate Workspace") {
          workspaceStore.validateWorkspace()
        }
      }

      Text(workspaceStore.validation.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let validationErrorMessage = workspaceStore.validationErrorMessage {
        ContentUnavailableView(
          "Validation Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(validationErrorMessage)
        )
      } else {
        List(issues.indices, id: \.self) { index in
          let issue = issues[index]

          Button {
            let navigationTarget = diagnosticsNavigationTarget(for: issue)
            selection = navigationTarget.sidebarItem
            selectedLibraryItemID = navigationTarget.selectedLibraryItemID
            searchText = navigationTarget.searchText
          } label: {
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
          .buttonStyle(.plain)
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

  private func sidebarItem(for entityType: WorkspaceValidationEntityType) -> SidebarItem {
    switch entityType {
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

private enum SidebarItem: Hashable {
  case sessions
  case personas
  case directives
  case kits
  case essentials
  case skills
  case intents
  case validationResults

  static let libraryItems: [SidebarItem] = [
    .personas,
    .directives,
    .kits,
    .essentials,
    .skills,
    .intents,
  ]

  var title: String {
    switch self {
    case .sessions:
      return "Sessions"
    case .personas:
      return "Personas"
    case .directives:
      return "Directives"
    case .kits:
      return "Kits"
    case .essentials:
      return "Essentials"
    case .skills:
      return "Skills"
    case .intents:
      return "Intents"
    case .validationResults:
      return "Validation Results"
    }
  }

  var systemImage: String {
    switch self {
    case .sessions:
      return "clock.arrow.circlepath"
    case .personas:
      return "person.2"
    case .directives:
      return "list.bullet.rectangle.portrait"
    case .kits:
      return "shippingbox"
    case .essentials:
      return "doc.text"
    case .skills:
      return "hammer"
    case .intents:
      return "scope"
    case .validationResults:
      return "checklist"
    }
  }
}
