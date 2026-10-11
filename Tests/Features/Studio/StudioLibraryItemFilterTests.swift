import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryItemFilterTests {
  private let items = [
    WorkspaceListItem(
      id: "solo-developer",
      displayName: "Solo Developer",
      fileURL: URL(fileURLWithPath: "/tmp/solo-developer.persona.json"),
      sourceScope: .project
    ),
    WorkspaceListItem(
      id: "release-manager",
      displayName: "Release Captain",
      fileURL: URL(fileURLWithPath: "/tmp/release-manager.persona.json"),
      sourceScope: .global
    ),
  ]

  @Test
  func blankSearchKeepsEveryItemInOrder() {
    #expect(
      StudioLibraryItemFilter.filteredItems(items, searchText: "  \n").map(\.id)
        == ["solo-developer", "release-manager"]
    )
  }

  @Test
  func searchMatchesIDOrDisplayNameCaseInsensitively() {
    #expect(
      StudioLibraryItemFilter.filteredItems(items, searchText: "SOLO-dev").map(\.id)
        == ["solo-developer"]
    )
    #expect(
      StudioLibraryItemFilter.filteredItems(items, searchText: " captain ").map(\.id)
        == ["release-manager"]
    )
    #expect(StudioLibraryItemFilter.filteredItems(items, searchText: "kit").isEmpty)
  }
}
