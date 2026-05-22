import Foundation

@MainActor
enum StudioWorkspaceOpenCoordinator {
  static func openWorkspaceFromPicker(
    workspaceStore: WorkspaceStore,
    recentWorkspacesStorageValue: inout String,
    recentWorkspaceAccess: StudioRecentWorkspaceAccessing,
    bookmarkDataProvider: (URL) -> Data? = StudioRecentWorkspacesState.securityScopedBookmarkData
  ) {
    let previousWorkspaceURL = workspaceStore.workspaceURL?.standardizedFileURL

    workspaceStore.openWorkspacePicker()

    guard workspaceStore.workspaceURL?.standardizedFileURL != previousWorkspaceURL else {
      return
    }

    recentWorkspaceAccess.stop()
    recordCurrentWorkspaceIfLoaded(
      workspaceStore: workspaceStore,
      recentWorkspacesStorageValue: &recentWorkspacesStorageValue,
      bookmarkDataProvider: bookmarkDataProvider
    )
  }

  static func openRecentWorkspace(
    _ workspace: StudioRecentWorkspace,
    workspaceStore: WorkspaceStore,
    recentWorkspacesStorageValue: inout String,
    recentWorkspaceAccess: StudioRecentWorkspaceAccessing
  ) {
    let workspaceURL = recentWorkspaceAccess.url(for: workspace)

    workspaceStore.workspaceURL = workspaceURL
    workspaceStore.loadWorkspace()
    recentWorkspacesStorageValue = StudioRecentWorkspacesState.storageValue(
      adding: workspaceURL,
      bookmarkData: workspace.bookmarkData,
      to: recentWorkspacesStorageValue
    )
  }

  static func recordCurrentWorkspaceIfLoaded(
    workspaceStore: WorkspaceStore,
    recentWorkspacesStorageValue: inout String,
    bookmarkDataProvider: (URL) -> Data? = StudioRecentWorkspacesState.securityScopedBookmarkData
  ) {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    recentWorkspacesStorageValue = StudioRecentWorkspacesState.storageValue(
      adding: workspaceURL,
      bookmarkData: bookmarkDataProvider(workspaceURL),
      to: recentWorkspacesStorageValue
    )
  }
}
