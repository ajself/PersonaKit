import PersonaKitCore
import SwiftUI

/// Root Studio split view with sidebar navigation and read-only list content.
struct StudioRootView: View {
  let workspaceStore: WorkspaceStore
  @State private var selection: SidebarItem? = .sessions
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
    .onChange(of: selection) {
      searchText = ""
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
        sessionsView
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
        ContentUnavailableView(
          "Validation Results",
          systemImage: "checklist",
          description: Text("Milestone 2 will add validation diagnostics.")
        )
      }
    }
  }

  private var sessionsView: some View {
    let items = filteredSessions(workspaceStore.snapshot.sessions)

    return List(items, id: \.id) { session in
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(session.id)
            .font(.headline)

          Spacer()

          scopeBadge(scope: session.sourceScope)
        }

        Text("persona: \(session.personaId) · directive: \(session.directiveId)")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Text(session.fileURL.path())
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
          .textSelection(.enabled)
      }
      .padding(.vertical, 4)
    }
    .searchable(text: $searchText, prompt: "Search Sessions")
    .overlay {
      if items.isEmpty {
        ContentUnavailableView.search
      }
    }
  }

  private func libraryListView(items: [WorkspaceListItem]) -> some View {
    List(items, id: \.id) { item in
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

  private func filteredSessions(_ items: [WorkspaceSessionListItem]) -> [WorkspaceSessionListItem] {
    let normalizedSearch = normalizedSearchText

    guard !normalizedSearch.isEmpty else {
      return items
    }

    return items.filter { item in
      item.id.localizedCaseInsensitiveContains(normalizedSearch)
        || item.personaId.localizedCaseInsensitiveContains(normalizedSearch)
        || item.directiveId.localizedCaseInsensitiveContains(normalizedSearch)
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
