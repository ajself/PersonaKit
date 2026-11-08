import Foundation

@MainActor
enum StudioWorkspaceOpenCoordinator {
  static func openWorkspaceFromPicker(
    workspaceStore: WorkspaceStore
  ) {
    guard workspaceStore.pickAndLoadWorkspace() else {
      return
    }

    // Record a re-pick of the open folder too: its new bookmark replaces a saved one that no longer opens it.
    workspaceStore.stopRecentWorkspaceAccess()
    workspaceStore.recordPickedWorkspaceIfLoaded()
  }

  static func openRecentWorkspace(
    _ workspace: StudioRecentWorkspace,
    workspaceStore: WorkspaceStore
  ) {
    let accessedWorkspace = workspaceStore.accessRecentWorkspace(workspace)

    workspaceStore.workspaceURL = accessedWorkspace.url
    workspaceStore.loadWorkspace()
    // A bookmark that now resolves to a moved folder records the new path, so the old entry goes.
    workspaceStore.recordRecentWorkspace(
      workspaceURL: accessedWorkspace.url,
      bookmarkData: accessedWorkspace.bookmarkData,
      replacing: accessedWorkspace.path == workspace.path ? nil : workspace
    )
  }
}
