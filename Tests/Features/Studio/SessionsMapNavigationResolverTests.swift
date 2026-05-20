import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct SessionsMapNavigationResolverTests {
  @Test
  func sessionNodeReturnsNilWhenSelectedSessionIDIsMissing() {
    let target = SessionsMapNavigationResolver.navigationTarget(
      for: makeNode(
        id: "active-session",
        kind: .session
      ),
      selectedSessionID: nil
    )

    #expect(target == nil)
  }

  @Test
  func sessionNodeReturnsNilForSyntheticSelectedSessionID() {
    let target = SessionsMapNavigationResolver.navigationTarget(
      for: makeNode(
        id: "active-session",
        kind: .session
      ),
      selectedSessionID: "active-session"
    )

    #expect(target == nil)
  }

  @Test
  func sessionNodeNavigatesToRealSelectedSessionID() throws {
    let target = try #require(
      SessionsMapNavigationResolver.navigationTarget(
        for: makeNode(
          id: "active-session",
          kind: .session
        ),
        selectedSessionID: "session-a"
      )
    )

    #expect(target.sidebarItem == .sessions)
    #expect(target.selectedLibraryItemID == nil)
    #expect(target.selectedSessionID == "session-a")
    #expect(target.searchText == "")
  }

  @Test
  func referenceNodeNavigatesToReferencesLibrary() throws {
    let target = try #require(
      SessionsMapNavigationResolver.navigationTarget(
        for: makeNode(
          id: "swift-style-guide-reference",
          kind: .reference
        ),
        selectedSessionID: "session-a"
      )
    )

    #expect(target.sidebarItem == .references)
    #expect(target.selectedLibraryItemID == "swift-style-guide-reference")
    #expect(target.selectedSessionID == nil)
    #expect(target.searchText == "")
  }

  private func makeNode(
    id: String,
    kind: WorkspaceSessionMapNodeKind
  ) -> WorkspaceSessionMapNode {
    WorkspaceSessionMapNode(
      key: "\(kind.rawValue):\(id)",
      id: id,
      displayName: id,
      kind: kind,
      isMissing: false,
      badges: []
    )
  }
}
