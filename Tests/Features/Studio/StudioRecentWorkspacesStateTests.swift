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
}
