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
    workspaceStore.recordCurrentWorkspaceIfLoaded()
  }

  static func openRecentWorkspace(
    _ workspace: StudioRecentWorkspace,
    workspaceStore: WorkspaceStore
  ) {
    let accessedWorkspace = workspaceStore.accessRecentWorkspace(workspace)

    workspaceStore.workspaceURL = accessedWorkspace.url
    workspaceStore.loadWorkspace()
    workspaceStore.recordRecentWorkspace(
      workspaceURL: accessedWorkspace.url,
      bookmarkData: accessedWorkspace.bookmarkData
    )
  }

  static func recordCurrentWorkspaceIfLoaded(
    workspaceStore: WorkspaceStore
  ) {
    workspaceStore.recordCurrentWorkspaceIfLoaded()
  }
}
