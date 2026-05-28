import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioRecentWorkspacesStateTests {
  @Test
  func addingWorkspaceStoresMostRecentFirstAndDeduplicates() {
    var storageValue = "[]"

    storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/A"),
      to: storageValue
    )
    storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/B"),
      to: storageValue
    )
    storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/A"),
      to: storageValue
    )

    #expect(
      StudioRecentWorkspacesState.workspaces(from: storageValue).map(\.path) == [
        "/Workspace/A",
        "/Workspace/B",
      ]
    )
  }

  @Test
  func addingWorkspaceStoresBookmarkData() {
    let bookmarkData = Data([1, 2, 3])
    let storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/A"),
      bookmarkData: bookmarkData,
      to: "[]"
    )

    #expect(
      StudioRecentWorkspacesState.workspaces(from: storageValue).first?.bookmarkData
        == bookmarkData
    )
  }

  @Test
  func readdingWorkspaceWithoutBookmarkPreservesExistingBookmarkData() {
    let bookmarkData = Data([1, 2, 3])
    let storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/A"),
      to: StudioRecentWorkspacesState.storageValue(
        adding: URL(fileURLWithPath: "/Workspace/A"),
        bookmarkData: bookmarkData,
        to: "[]"
      )
    )

    #expect(
      StudioRecentWorkspacesState.workspaces(from: storageValue).first?.bookmarkData
        == bookmarkData
    )
  }

  @Test
  func oldPathOnlyStorageStillDecodes() {
    let storageValue = #"["/Workspace/A","/Workspace/B"]"#

    #expect(
      StudioRecentWorkspacesState.workspaces(from: storageValue).map(\.path) == [
        "/Workspace/A",
        "/Workspace/B",
      ]
    )
  }

  @Test
  func removingWorkspaceDropsOnlyMatchingPath() {
    let storageValue = StudioRecentWorkspacesState.storageValue(
      adding: URL(fileURLWithPath: "/Workspace/B"),
      to: StudioRecentWorkspacesState.storageValue(
        adding: URL(fileURLWithPath: "/Workspace/A"),
        to: "[]"
      )
    )

    let removedValue = StudioRecentWorkspacesState.storageValue(
      removing: StudioRecentWorkspace(path: "/Workspace/A"),
      from: storageValue
    )

    #expect(
      StudioRecentWorkspacesState.workspaces(from: removedValue).map(\.path) == [
        "/Workspace/B"
      ]
    )
  }

  @Test
  func malformedStorageFallsBackToNoRecentWorkspaces() {
    #expect(StudioRecentWorkspacesState.workspaces(from: "not json").isEmpty)
  }

  @Test
  func securityScopedBookmarkDataUsesInjectedBookmarkClient() {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/A")
    let bookmarkData = Data([8, 9, 10])
    let bookmarkClient = StudioRecentWorkspaceBookmarkRecorder(
      bookmarkData: bookmarkData
    )

    let resolvedData = StudioRecentWorkspacesState.securityScopedBookmarkData(
      for: workspaceURL,
      bookmarkClient: bookmarkClient
    )

    #expect(resolvedData == bookmarkData)
    #expect(bookmarkClient.requestedURLs == [workspaceURL])
  }

  @Test
  func addingWorkspaceKeepsOnlyMaximumRecentPaths() {
    var storageValue = "[]"

    for index in 1...8 {
      storageValue = StudioRecentWorkspacesState.storageValue(
        adding: URL(fileURLWithPath: "/Workspace/\(index)"),
        to: storageValue
      )
    }

    #expect(
      StudioRecentWorkspacesState.workspaces(from: storageValue).map(\.path) == [
        "/Workspace/8",
        "/Workspace/7",
        "/Workspace/6",
        "/Workspace/5",
        "/Workspace/4",
        "/Workspace/3",
      ]
    )
  }

  @Test
  @MainActor
  func workspaceOpenCoordinatorRecordsPickerWorkspaceAndStopsRecentAccess() async {
    let selectedWorkspaceURL = URL(fileURLWithPath: "/PickedWorkspace")
    let recentAccess = StudioRecentWorkspaceAccessRecorder()
    let storage = StudioRecentWorkspacesStorageRecorder()
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        #expect(workspaceURL.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL)
        return WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspacePicker: WorkspaceStoreStubWorkspacePicker(
        selectedURL: selectedWorkspaceURL
      )
    )
    store.configureRecentWorkspaces(
      storage: storage,
      recentWorkspaceAccess: recentAccess,
      bookmarkDataProvider: { _ in Data([4, 5, 6]) }
    )

    StudioWorkspaceOpenCoordinator.openWorkspaceFromPicker(workspaceStore: store)

    await waitFor {
      store.workspaceURL?.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL
    }

    #expect(recentAccess.stopCount == 1)
    #expect(store.recentWorkspaces.map(\.path) == ["/PickedWorkspace"])
    #expect(store.recentWorkspaces.first?.bookmarkData == Data([4, 5, 6]))
    #expect(
      StudioRecentWorkspacesState.workspaces(from: storage.storageValue).map(\.path)
        == ["/PickedWorkspace"]
    )
  }

  @Test
  @MainActor
  func workspaceOpenCoordinatorSkipsRecentChangesWhenPickerReturnsSameWorkspace() {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let recentAccess = StudioRecentWorkspaceAccessRecorder()
    let storage = StudioRecentWorkspacesStorageRecorder()
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspacePicker: WorkspaceStoreStubWorkspacePicker(
        selectedURL: workspaceURL
      )
    )
    store.configureRecentWorkspaces(
      storage: storage,
      recentWorkspaceAccess: recentAccess,
      bookmarkDataProvider: { _ in Data([4, 5, 6]) }
    )
    store.workspaceURL = workspaceURL

    StudioWorkspaceOpenCoordinator.openWorkspaceFromPicker(workspaceStore: store)

    #expect(recentAccess.stopCount == 0)
    #expect(store.recentWorkspaces.isEmpty)
    #expect(StudioRecentWorkspacesState.workspaces(from: storage.storageValue).isEmpty)
  }

  @Test
  @MainActor
  func workspaceOpenCoordinatorOpensRecentWorkspaceThroughStoreOwner() async {
    let recentAccess = StudioRecentWorkspaceAccessRecorder()
    let storage = StudioRecentWorkspacesStorageRecorder()
    let expectedWorkspaceURL = URL(
      fileURLWithPath: "/RecentWorkspace",
      isDirectory: true
    )
    .standardizedFileURL
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        #expect(workspaceURL.standardizedFileURL == expectedWorkspaceURL)
        return WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      }
    )
    store.configureRecentWorkspaces(
      storage: storage,
      recentWorkspaceAccess: recentAccess
    )
    let recentWorkspace = StudioRecentWorkspace(
      path: "/RecentWorkspace",
      bookmarkData: Data([7, 8, 9])
    )

    StudioWorkspaceOpenCoordinator.openRecentWorkspace(
      recentWorkspace,
      workspaceStore: store
    )

    await waitFor {
      store.workspaceURL?.standardizedFileURL == expectedWorkspaceURL
    }

    #expect(recentAccess.requestedWorkspaces == [recentWorkspace])
    #expect(store.recentWorkspaces == [recentWorkspace])
    #expect(
      StudioRecentWorkspacesState.workspaces(from: storage.storageValue)
        == [recentWorkspace]
    )
  }

  @Test
  @MainActor
  func recentWorkspaceAccessUsesInjectedSecurityScopeClient() {
    let bookmarkData = Data([1, 2, 3])
    let resolvedURL = URL(fileURLWithPath: "/ResolvedWorkspace")
    let securityScopeClient = StudioRecentWorkspaceSecurityScopeRecorder(
      resolvedURL: resolvedURL,
      shouldStartAccess: true
    )
    let access = StudioRecentWorkspaceAccess(securityScopeClient: securityScopeClient)

    let url = access.url(
      for: StudioRecentWorkspace(
        path: "/FallbackWorkspace",
        bookmarkData: bookmarkData
      )
    )
    access.stop()

    #expect(url == resolvedURL.standardizedFileURL)
    #expect(securityScopeClient.resolvedBookmarkData == [bookmarkData])
    #expect(securityScopeClient.startedURLs == [resolvedURL.standardizedFileURL])
    #expect(securityScopeClient.stoppedURLs == [resolvedURL.standardizedFileURL])
  }
}

private final class StudioRecentWorkspaceAccessRecorder: StudioRecentWorkspaceAccessing {
  private(set) var stopCount = 0
  private(set) var requestedWorkspaces: [StudioRecentWorkspace] = []

  func url(for workspace: StudioRecentWorkspace) -> URL {
    requestedWorkspaces.append(workspace)

    return workspace.url
  }

  func stop() {
    stopCount += 1
  }
}

private final class StudioRecentWorkspacesStorageRecorder: StudioRecentWorkspacesPersisting {
  var storageValue: String

  init(storageValue: String = "[]") {
    self.storageValue = storageValue
  }
}

private final class StudioRecentWorkspaceBookmarkRecorder: StudioRecentWorkspaceBookmarking {
  private let bookmarkData: Data?
  private(set) var requestedURLs: [URL] = []

  init(bookmarkData: Data?) {
    self.bookmarkData = bookmarkData
  }

  func bookmarkData(for workspaceURL: URL) -> Data? {
    requestedURLs.append(workspaceURL)
    return bookmarkData
  }
}

private final class StudioRecentWorkspaceSecurityScopeRecorder:
  StudioRecentWorkspaceSecurityScopeResolving
{
  private let resolvedURL: URL?
  private let shouldStartAccess: Bool
  private(set) var resolvedBookmarkData: [Data] = []
  private(set) var startedURLs: [URL] = []
  private(set) var stoppedURLs: [URL] = []

  init(
    resolvedURL: URL?,
    shouldStartAccess: Bool
  ) {
    self.resolvedURL = resolvedURL?.standardizedFileURL
    self.shouldStartAccess = shouldStartAccess
  }

  func resolveURL(from bookmarkData: Data) -> URL? {
    resolvedBookmarkData.append(bookmarkData)
    return resolvedURL
  }

  func startAccessing(_ url: URL) -> Bool {
    startedURLs.append(url.standardizedFileURL)
    return shouldStartAccess
  }

  func stopAccessing(_ url: URL) {
    stoppedURLs.append(url.standardizedFileURL)
  }
}
