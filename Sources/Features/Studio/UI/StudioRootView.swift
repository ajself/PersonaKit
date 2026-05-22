import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Root Studio split view with sidebar navigation, session editing, and diagnostics.
public struct StudioRootView: View {
  let workspaceStore: WorkspaceStore
  @AppStorage(
    StudioRecentWorkspacesState.storageKey,
    store: StudioLaunchConfiguration.userDefaults()
  )
  private var recentWorkspacesStorageValue = "[]"
  @State private var selection: SidebarItem?
  @State private var selectedLibraryItemID: String?
  @State private var selectedSessionID: String?
  @State private var searchTextBySidebarItem: [SidebarItem: String] = [:]
  @State private var sidebarVisibility = NavigationSplitViewVisibility.all
  @SceneStorage("studio.inspector.isPresented")
  private var isInspectorPresented = false
  @SceneStorage(StudioInspectorMode.storageKey)
  private var inspectorModeRawValue = StudioInspectorMode.primary.rawValue

  public init(
    workspaceStore: WorkspaceStore,
    initialSection: StudioLaunchSection = .sessions
  ) {
    self.workspaceStore = workspaceStore
    self._selection = State(initialValue: SidebarItem(section: initialSection))
  }

  public var body: some View {
    NavigationSplitView(columnVisibility: $sidebarVisibility) {
      StudioSidebarView(selection: $selection)
        .navigationTitle("PersonaKit Studio")
    } detail: {
      detailView
    }
    .toolbar {
      if !sidebarIsVisible {
        ToolbarItem(placement: .navigation) {
          Button {
            toggleCustomSidebarVisibility()
          } label: {
            Label(sidebarToggleTitle, systemImage: "sidebar.leading")
          }
          .accessibilityLabel(sidebarToggleTitle)
          .accessibilityValue(sidebarIsVisible ? "Shown" : "Hidden")
          .help(sidebarToggleTitle)
        }
      }

      if let workspaceSummaryState {
        ToolbarItem(placement: .principal) {
          StudioWorkspaceSummaryView(
            state: workspaceSummaryState,
            onNavigate: { sidebarItem in
              navigateToWorkspaceSection(sidebarItem)
            },
            onRevealWorkspace: {
              revealLoadedWorkspace()
            }
          )
        }
      }

      if shouldShowInspectorToggle {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showInspectorHelp()
          } label: {
            Label("Help", systemImage: "questionmark.circle")
          }
          .accessibilityLabel("Help")
          .help("Show Help in Inspector")
        }

        ToolbarItem(placement: .primaryAction) {
          Button {
            isInspectorPresented.toggle()
          } label: {
            Label("Inspector", systemImage: "sidebar.trailing")
          }
          .accessibilityLabel("Inspector")
          .accessibilityValue(isInspectorPresented ? "Shown" : "Hidden")
          .help(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
        }
      }
    }
    .task {
      let previousWorkspaceURL = workspaceStore.workspaceURL
      workspaceStore.loadLaunchWorkspaceIfNeeded()

      if workspaceStore.workspaceURL != previousWorkspaceURL {
        recordCurrentWorkspaceIfLoaded()
      }

      workspaceStore.refreshInstallStatus()
    }
    .alert(
      workspaceStore.installResult?.title ?? "",
      isPresented: Binding(
        get: {
          workspaceStore.installResult != nil
        },
        set: { isPresented in
          if !isPresented {
            workspaceStore.dismissInstallResult()
          }
        }
      ),
      presenting: workspaceStore.installResult
    ) { _ in
      Button("OK") {
        workspaceStore.dismissInstallResult()
      }
    } message: { result in
      Text(result.message)
    }
  }

  @ViewBuilder
  private var detailView: some View {
    if workspaceStore.workspaceURL == nil {
      StudioWelcomeView(
        recentWorkspaces: recentWorkspaces,
        onOpenWorkspace: {
          openWorkspaceFromPicker()
        },
        onOpenRecentWorkspace: { workspace in
          openRecentWorkspace(workspace)
        },
        onRemoveRecentWorkspace: { workspace in
          removeRecentWorkspace(workspace)
        }
      )
    } else if let loadErrorMessage = workspaceStore.loadErrorMessage {
      if workspaceStore.canInitializeWorkspaceStructure {
        StudioWorkspaceInitializationView(
          loadErrorMessage: loadErrorMessage,
          onInitialize: {
            workspaceStore.initializeWorkspaceStructure()
          },
          onChooseAnotherFolder: {
            openWorkspaceFromPicker()
          }
        )
      } else {
        ContentUnavailableView(
          label: {
            Label("Workspace Load Failed", systemImage: "exclamationmark.triangle")
          },
          description: {
            Text("\(loadErrorMessage) Choose another folder to inspect a different PersonaKit root.")
          },
          actions: {
            Button("Choose Another Folder") {
              openWorkspaceFromPicker()
            }
            .accessibilityLabel("Choose Another Folder")
            .help("Choose Another Folder")
          }
        )
      }
    } else {
      let activeSelection = selection ?? .sessions

      loadedWorkspaceView(activeSelection: activeSelection)
    }
  }

  private var recentWorkspaces: [StudioRecentWorkspace] {
    StudioRecentWorkspacesState.workspaces(from: recentWorkspacesStorageValue)
  }

  private var shouldShowInspectorToggle: Bool {
    guard workspaceStore.workspaceURL != nil,
      workspaceStore.loadErrorMessage == nil
    else {
      return false
    }

    return (selection ?? .sessions).supportsInspector
  }

  private var inspectorModeBinding: Binding<StudioInspectorMode> {
    Binding(
      get: {
        StudioInspectorMode.resolved(rawValue: inspectorModeRawValue)
      },
      set: { mode in
        inspectorModeRawValue = mode.rawValue
      }
    )
  }

  private var sidebarIsVisible: Bool {
    sidebarVisibility != .detailOnly
  }

  private var sidebarToggleTitle: String {
    sidebarIsVisible ? "Hide Sidebar" : "Show Sidebar"
  }

  private func toggleCustomSidebarVisibility() {
    sidebarVisibility = sidebarIsVisible ? .detailOnly : .all
  }

  @ViewBuilder
  private func loadedWorkspaceView(
    activeSelection: SidebarItem
  ) -> some View {
    switch activeSelection {
    case .sessions:
      SessionsPanelView(
        workspaceStore: workspaceStore,
        searchText: searchTextBinding(for: .sessions),
        selectedSessionID: $selectedSessionID,
        isInspectorPresented: $isInspectorPresented,
        inspectorMode: inspectorModeBinding,
        onNavigate: { target in
          applyNavigationTarget(target)
        },
        onNavigateHelpLink: { link in
          applyHelpLink(link)
        }
      )

    case .relationshipMap:
      WorkspaceRelationshipMapPanelView(
        workspaceStore: workspaceStore,
        searchText: searchTextBinding(for: .relationshipMap),
        isInspectorPresented: $isInspectorPresented,
        inspectorMode: inspectorModeBinding,
        onNavigate: { target in
          applyNavigationTarget(target)
        },
        onNavigateHelpLink: { link in
          applyHelpLink(link)
        }
      )

    case .personas,
      .directives,
      .kits,
      .essentials,
      .references,
      .skills,
      .intents:
      StudioLibraryPanelView(
        workspaceStore: workspaceStore,
        selection: activeSelection,
        items: libraryItems(for: activeSelection),
        searchText: searchTextBinding(for: activeSelection),
        selectedLibraryItemID: $selectedLibraryItemID,
        isInspectorPresented: $isInspectorPresented,
        inspectorMode: inspectorModeBinding,
        onNavigateHelpLink: { link in
          applyHelpLink(link)
        }
      )

    case .validationResults:
      StudioDiagnosticsPanelView(
        workspaceStore: workspaceStore,
        searchText: searchTextBinding(for: .validationResults),
        isInspectorPresented: $isInspectorPresented,
        inspectorMode: inspectorModeBinding,
        onNavigate: { target in
          applyNavigationTarget(target)
        }
      )
    }
  }

  private var workspaceSummaryState: StudioWorkspaceSummaryState? {
    guard
      let workspaceURL = workspaceStore.workspaceURL,
      workspaceStore.loadErrorMessage == nil
    else {
      return nil
    }

    return StudioWorkspaceSummaryState(
      workspaceURL: workspaceURL,
      snapshot: workspaceStore.snapshot,
      validation: workspaceStore.validation,
      validationErrorMessage: workspaceStore.validationErrorMessage
    )
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
    case .references:
      return workspaceStore.snapshot.references
    case .skills:
      return workspaceStore.snapshot.skills
    case .intents:
      return workspaceStore.snapshot.intents
    default:
      return []
    }
  }

  private func applyNavigationTarget(_ target: StudioNavigationTarget) {
    var state = StudioRootNavigationState(
      selection: selection,
      selectedLibraryItemID: selectedLibraryItemID,
      selectedSessionID: selectedSessionID,
      searchTextBySidebarItem: searchTextBySidebarItem
    )

    state.apply(target)

    selection = state.selection
    selectedLibraryItemID = state.selectedLibraryItemID
    selectedSessionID = state.selectedSessionID
    searchTextBySidebarItem = state.searchTextBySidebarItem
  }

  private func applyHelpLink(_ link: StudioHelpLink) {
    applyNavigationTarget(
      StudioNavigationTarget(
        sidebarItem: link.destination,
        searchText: link.searchText ?? ""
      )
    )
  }

  private func showInspectorHelp() {
    inspectorModeRawValue = StudioInspectorMode.help.rawValue
    isInspectorPresented = true
  }

  private func navigateToWorkspaceSection(_ sidebarItem: SidebarItem) {
    selection = sidebarItem
    selectedLibraryItemID = nil
    searchTextBySidebarItem[sidebarItem] = ""
  }

  private func searchTextBinding(
    for sidebarItem: SidebarItem
  ) -> Binding<String> {
    Binding(
      get: {
        searchTextBySidebarItem[sidebarItem, default: ""]
      },
      set: { searchText in
        searchTextBySidebarItem[sidebarItem] = searchText
      }
    )
  }

  private func revealLoadedWorkspace() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    workspaceStore.revealInFinder(fileURL: workspaceURL)
  }

  private func openWorkspaceFromPicker() {
    StudioWorkspaceOpenCoordinator.openWorkspaceFromPicker(
      workspaceStore: workspaceStore,
      recentWorkspacesStorageValue: &recentWorkspacesStorageValue,
      recentWorkspaceAccess: workspaceStore.recentWorkspaceAccess
    )
  }

  private func openRecentWorkspace(_ workspace: StudioRecentWorkspace) {
    StudioWorkspaceOpenCoordinator.openRecentWorkspace(
      workspace,
      workspaceStore: workspaceStore,
      recentWorkspacesStorageValue: &recentWorkspacesStorageValue,
      recentWorkspaceAccess: workspaceStore.recentWorkspaceAccess
    )
  }

  private func removeRecentWorkspace(_ workspace: StudioRecentWorkspace) {
    recentWorkspacesStorageValue = StudioRecentWorkspacesState.storageValue(
      removing: workspace,
      from: recentWorkspacesStorageValue
    )
  }

  private func recordCurrentWorkspaceIfLoaded() {
    StudioWorkspaceOpenCoordinator.recordCurrentWorkspaceIfLoaded(
      workspaceStore: workspaceStore,
      recentWorkspacesStorageValue: &recentWorkspacesStorageValue
    )
  }
}

enum SidebarItem: Hashable {
  case sessions
  case personas
  case directives
  case kits
  case essentials
  case references
  case skills
  case intents
  case relationshipMap
  case validationResults

  static let contractItems: [SidebarItem] = [
    .personas,
    .directives,
    .kits,
    .intents,
  ]

  static let contextItems: [SidebarItem] = [
    .essentials,
    .references,
    .skills,
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
    case .references:
      return "References"
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
    case .personas:
      return "person.2"
    case .directives:
      return "list.bullet.rectangle.portrait"
    case .kits:
      return "shippingbox"
    case .essentials:
      return "doc.text"
    case .references:
      return "book.closed"
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

  var supportsInspector: Bool {
    switch self {
    case .sessions,
      .personas,
      .directives,
      .kits,
      .essentials,
      .references,
      .skills,
      .intents,
      .relationshipMap,
      .validationResults:
      return true
    }
  }

  init(section: StudioLaunchSection) {
    switch section {
    case .directives:
      self = .directives
    case .essentials:
      self = .essentials
    case .intents:
      self = .intents
    case .kits:
      self = .kits
    case .personas:
      self = .personas
    case .references:
      self = .references
    case .relationshipMap:
      self = .relationshipMap
    case .sessions:
      self = .sessions
    case .skills:
      self = .skills
    case .validationResults:
      self = .validationResults
    }
  }
}
