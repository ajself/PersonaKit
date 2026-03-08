import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Root Studio split view with sidebar navigation, session editing, and diagnostics.
public struct StudioRootView: View {
  let workspaceStore: WorkspaceStore
  @State private var selection: SidebarItem? = .sessions
  @State private var selectedLibraryItemID: String?
  @State private var searchText = ""

  public init(workspaceStore: WorkspaceStore) {
    self.workspaceStore = workspaceStore
  }

  public var body: some View {
    NavigationSplitView {
      StudioSidebarView(selection: $selection)
        .navigationTitle("PersonaKit Studio")
    } detail: {
      detailView
    }
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
      if workspaceStore.canInitializeWorkspaceStructure {
        StudioWorkspaceInitializationView(
          loadErrorMessage: loadErrorMessage,
          onInitialize: {
            workspaceStore.initializeWorkspaceStructure()
          },
          onChooseAnotherFolder: {
            workspaceStore.openWorkspacePicker()
          }
        )
      } else {
        ContentUnavailableView(
          "Workspace Load Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(loadErrorMessage)
        )
      }
    } else {
      let activeSelection = selection ?? .sessions

      switch activeSelection {
      case .sessions:
        SessionsPanelView(
          workspaceStore: workspaceStore,
          searchText: $searchText,
          onNavigate: { target in
            applyNavigationTarget(target)
          }
        )

      case .relationshipMap:
        WorkspaceRelationshipMapPanelView(
          workspaceStore: workspaceStore,
          searchText: $searchText,
          onNavigate: { target in
            applyNavigationTarget(target)
          }
        )

      case .taskboard:
        TaskboardPanelView(workspaceStore: workspaceStore)

      case .personas,
        .directives,
        .kits,
        .essentials,
        .skills,
        .intents:
        StudioLibraryPanelView(
          workspaceStore: workspaceStore,
          selection: activeSelection,
          items: libraryItems(for: activeSelection),
          searchText: $searchText,
          selectedLibraryItemID: $selectedLibraryItemID
        )

      case .validationResults:
        StudioDiagnosticsPanelView(
          workspaceStore: workspaceStore,
          selection: $selection,
          selectedLibraryItemID: $selectedLibraryItemID,
          searchText: $searchText
        )
      }
    }
  }

  private func libraryItems(for sidebarItem: SidebarItem) -> [WorkspaceListItem] {
    switch sidebarItem {
    case .personas:
      return workspaceStore.snapshot.personas
    case .directives:
      return workspaceStore.snapshot.directives
    case .kits:
      return workspaceStore.snapshot.kits
    case .essentials:
      return workspaceStore.snapshot.essentials
    case .skills:
      return workspaceStore.snapshot.skills
    case .intents:
      return workspaceStore.snapshot.intents
    default:
      return []
    }
  }

  private func applyNavigationTarget(_ target: SessionsNavigationTarget) {
    var state = StudioRootNavigationState(
      selection: selection,
      selectedLibraryItemID: selectedLibraryItemID,
      searchText: searchText
    )

    state.apply(target)

    selection = state.selection
    selectedLibraryItemID = state.selectedLibraryItemID
    searchText = state.searchText
  }
}

enum SidebarItem: Hashable {
  case sessions
  case taskboard
  case personas
  case directives
  case kits
  case essentials
  case skills
  case intents
  case relationshipMap
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
    case .taskboard:
      return "Taskboard"
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
    case .relationshipMap:
      return "Relationship Map"
    case .validationResults:
      return "Validation Results"
    }
  }

  var systemImage: String {
    switch self {
    case .sessions:
      return "clock.arrow.circlepath"
    case .taskboard:
      return "rectangle.3.group.bubble.left"
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
    case .relationshipMap:
      return "point.3.filled.connected.trianglepath.dotted"
    case .validationResults:
      return "checklist"
    }
  }
}
