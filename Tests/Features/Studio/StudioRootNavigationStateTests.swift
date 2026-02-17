import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioRootNavigationStateTests {
  @Test
  func mapNodeDrillDownUpdatesRootSelectionAndSelectedItem() throws {
    let node = WorkspaceSessionMapNode(
      key: "persona:persona-a",
      id: "persona-a",
      displayName: "Persona A",
      kind: .persona,
      isMissing: false,
      badges: []
    )
    let target = try #require(
      SessionsMapNavigationResolver.navigationTarget(
        for: node,
        selectedSessionID: "session-a"
      )
    )

    var state = StudioRootNavigationState(
      selection: .sessions,
      selectedLibraryItemID: nil,
      searchText: ""
    )

    state.apply(target)

    #expect(state.selection == .personas)
    #expect(state.selectedLibraryItemID == "persona-a")
    #expect(state.searchText == "persona-a")
  }

  @Test
  func sessionMapNodeDrillDownUpdatesRootSessionSearchState() throws {
    let node = WorkspaceSessionMapNode(
      key: "session:active-session",
      id: "active-session",
      displayName: "Active Session",
      kind: .session,
      isMissing: false,
      badges: []
    )
    let target = try #require(
      SessionsMapNavigationResolver.navigationTarget(
        for: node,
        selectedSessionID: "session-a"
      )
    )

    var state = StudioRootNavigationState(
      selection: .relationshipMap,
      selectedLibraryItemID: "persona-a",
      searchText: "persona-a"
    )

    state.apply(target)

    #expect(state.selection == .sessions)
    #expect(state.selectedLibraryItemID == nil)
    #expect(state.searchText == "session-a")
  }
}
