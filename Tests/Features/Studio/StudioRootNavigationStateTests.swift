import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioRootNavigationStateTests {
  @Test
  func mapNodeOpenSelectsLibraryItemAndClearsDestinationSearchOnly() {
    let node = WorkspaceSessionMapNode(
      key: "persona:persona-a",
      id: "persona-a",
      displayName: "Persona A",
      kind: .persona,
      isMissing: false,
      badges: []
    )
    let target = SessionsMapNavigationResolver.navigationTarget(for: node)

    var state = StudioRootNavigationState(
      selection: .sessions,
      selectedLibraryItemID: nil,
      selectedSessionID: "session-a",
      searchTextBySidebarItem: [
        .personas: "prior-persona-search",
        .validationResults: "validation-search",
      ]
    )

    state.apply(target)

    #expect(state.selection == .personas)
    #expect(state.selectedLibraryItemID == "persona-a")
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.personas] == "")
    #expect(state.searchTextBySidebarItem[.validationResults] == "validation-search")
  }

  @Test
  func sessionMapNodeOpenSelectsSessionAndClearsDestinationSearchOnly() {
    let node = WorkspaceSessionMapNode(
      key: "session:session-a",
      id: "session-a",
      displayName: "session-a",
      kind: .session,
      isMissing: false,
      badges: []
    )
    let target = SessionsMapNavigationResolver.navigationTarget(for: node)

    var state = StudioRootNavigationState(
      selection: .personas,
      selectedLibraryItemID: "persona-a",
      selectedSessionID: nil,
      searchTextBySidebarItem: [
        .personas: "solo",
        .sessions: "prior-session-search",
      ]
    )

    state.apply(target)

    #expect(state.selection == .sessions)
    #expect(state.selectedLibraryItemID == nil)
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.personas] == "solo")
    #expect(state.searchTextBySidebarItem[.sessions] == "")
  }

  @Test
  func explicitNavigationSearchUpdatesOnlyDestinationSearch() {
    let target = StudioNavigationTarget(
      sidebarItem: .validationResults,
      searchText: "missing reference"
    )
    var state = StudioRootNavigationState(
      selection: .sessions,
      selectedLibraryItemID: nil,
      selectedSessionID: "session-a",
      searchTextBySidebarItem: [
        .sessions: "small-cli-change",
        .validationResults: "",
      ]
    )

    state.apply(target)

    #expect(state.selection == .validationResults)
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.sessions] == "small-cli-change")
    #expect(state.searchTextBySidebarItem[.validationResults] == "missing reference")
  }
}
