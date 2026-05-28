import Foundation

@MainActor
enum StudioWorkspaceOpenCoordinator {
  static func openWorkspaceFromPicker(
    workspaceStore: WorkspaceStore
  ) {
    let previousWorkspaceURL = workspaceStore.workspaceURL?.standardizedFileURL

    workspaceStore.openWorkspacePicker()

    guard workspaceStore.workspaceURL?.standardizedFileURL != previousWorkspaceURL else {
      return
    }

    workspaceStore.stopRecentWorkspaceAccess()
    workspaceStore.recordCurrentWorkspaceIfLoaded()
  }

  static func openRecentWorkspace(
    _ workspace: StudioRecentWorkspace,
    workspaceStore: WorkspaceStore
  ) {
    let workspaceURL = workspaceStore.url(forRecentWorkspace: workspace)

    workspaceStore.workspaceURL = workspaceURL
    workspaceStore.loadWorkspace()
    workspaceStore.recordRecentWorkspace(
      workspaceURL: workspaceURL,
      bookmarkData: workspace.bookmarkData
    )
  }

  static func recordCurrentWorkspaceIfLoaded(
    workspaceStore: WorkspaceStore
  ) {
    workspaceStore.recordCurrentWorkspaceIfLoaded()
  }
}
