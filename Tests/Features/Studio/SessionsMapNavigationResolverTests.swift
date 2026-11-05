import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct SessionsMapNavigationResolverTests {
  @Test
  func concreteSessionNodeNavigatesToItsOwnSessionID() {
    let target = SessionsMapNavigationResolver.navigationTarget(
      for: makeNode(
        id: "session-a",
        kind: .session
      )
    )

    #expect(target.sidebarItem == .sessions)
    #expect(target.selectedSessionID == "session-a")
    #expect(target.searchText == "")
  }

  @Test
  func skillNodeNavigatesToSkillsLibrary() {
    let target = SessionsMapNavigationResolver.navigationTarget(
      for: makeNode(
        id: "swift-style-guide-reference",
        kind: .skill
      )
    )

    #expect(target.sidebarItem == .skills)
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
