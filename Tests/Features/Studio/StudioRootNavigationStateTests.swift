import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioRootNavigationStateTests {
  @Test
  func everyWorkspaceSectionSupportsInspector() {
    let inspectorSections: [SidebarItem] = [
      .sessions,
      .personas,
      .directives,
      .kits,
      .essentials,
      .skills,
      .relationshipMap,
      .validationResults,
    ]

    for section in inspectorSections {
      #expect(section.supportsInspector)
    }
  }

  @Test
  func mapNodeOpenSelectsLibraryItemAndClearsDestinationSearchOnly() throws {
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
      selectedSessionID: "session-a",
      searchTextBySidebarItem: [
        .personas: "prior-persona-search",
        .relationshipMap: "map-search",
      ]
    )

    state.apply(target)

    #expect(state.selection == .personas)
    #expect(state.selectedLibraryItemID == "persona-a")
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.personas] == "")
    #expect(state.searchTextBySidebarItem[.relationshipMap] == "map-search")
  }

  @Test
  func sessionMapNodeOpenSelectsSessionAndClearsDestinationSearchOnly() throws {
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
      selectedSessionID: nil,
      searchTextBySidebarItem: [
        .relationshipMap: "small-cli-change",
        .sessions: "prior-session-search",
      ]
    )

    state.apply(target)

    #expect(state.selection == .sessions)
    #expect(state.selectedLibraryItemID == nil)
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.relationshipMap] == "small-cli-change")
    #expect(state.searchTextBySidebarItem[.sessions] == "")
  }

  @Test
  func explicitNavigationSearchUpdatesOnlyDestinationSearch() {
    let target = StudioNavigationTarget(
      sidebarItem: .validationResults,
      searchText: "missing reference"
    )
    var state = StudioRootNavigationState(
      selection: .relationshipMap,
      selectedLibraryItemID: nil,
      selectedSessionID: "session-a",
      searchTextBySidebarItem: [
        .relationshipMap: "small-cli-change",
        .validationResults: "",
      ]
    )

    state.apply(target)

    #expect(state.selection == .validationResults)
    #expect(state.selectedSessionID == "session-a")
    #expect(state.searchTextBySidebarItem[.relationshipMap] == "small-cli-change")
    #expect(state.searchTextBySidebarItem[.validationResults] == "missing reference")
  }
}
