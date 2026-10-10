import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct SessionsListRowStateTests {
  private let session = WorkspaceSessionListItem(
    id: "solo-dev",
    personaId: "solo-developer",
    directiveId: "small-cli-change",
    fileURL: URL(fileURLWithPath: "/tmp/.personakit/Sessions/solo-dev.session.json"),
    sourceScope: .project
  )

  private let snapshot = WorkspaceSnapshot(
    sessions: [],
    personas: [
      WorkspaceListItem(
        id: "solo-developer",
        displayName: "Solo Developer",
        fileURL: URL(fileURLWithPath: "/tmp/solo-developer.persona.json"),
        sourceScope: .project
      )
    ],
    directives: [
      WorkspaceListItem(
        id: "small-cli-change",
        displayName: "Make a small CLI change",
        fileURL: URL(fileURLWithPath: "/tmp/small-cli-change.directive.json"),
        sourceScope: .global
      )
    ],
    kits: [],
    skills: []
  )

  @Test
  func subtitleUsesPersonaAndDirectiveDisplayNames() {
    #expect(
      SessionsListRowState.subtitle(for: session, in: snapshot)
        == "Solo Developer · Make a small CLI change"
    )
  }

  @Test
  func subtitleFallsBackToIDsForUnresolvedReferences() {
    #expect(
      SessionsListRowState.subtitle(for: session, in: .empty)
        == "solo-developer · small-cli-change"
    )
  }

  @Test
  func searchMatchesIDsAndDisplayNames() {
    #expect(SessionsListRowState.matches(session, searchText: "", in: snapshot))
    #expect(SessionsListRowState.matches(session, searchText: "  ", in: snapshot))
    #expect(SessionsListRowState.matches(session, searchText: "SOLO-dev", in: snapshot))
    #expect(SessionsListRowState.matches(session, searchText: "small-cli", in: snapshot))
    #expect(SessionsListRowState.matches(session, searchText: "Solo Developer", in: snapshot))
    #expect(SessionsListRowState.matches(session, searchText: "cli change", in: snapshot))
    #expect(!SessionsListRowState.matches(session, searchText: "tmp", in: snapshot))
  }
}
