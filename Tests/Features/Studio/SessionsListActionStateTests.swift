import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct SessionsListActionStateTests {
  @Test
  func noSelectionDisablesSelectionAndDeleteActions() {
    let state = SessionsListActionState(
      selectedSession: nil,
      isLoadingSessionDraft: false
    )

    #expect(state.canCreate)
    #expect(!state.canEdit)
    #expect(!state.canReveal)
    #expect(!state.canDelete)
    #expect(!state.isLoadingDraft)
  }

  @Test
  func projectSelectionEnablesEditRevealAndDelete() {
    let state = SessionsListActionState(
      selectedSession: makeSession(scope: .project),
      isLoadingSessionDraft: false
    )

    #expect(state.canCreate)
    #expect(state.canEdit)
    #expect(state.canReveal)
    #expect(state.canDelete)
    #expect(!state.isLoadingDraft)
  }

  @Test
  func globalSelectionDisablesDelete() {
    let state = SessionsListActionState(
      selectedSession: makeSession(scope: .global),
      isLoadingSessionDraft: false
    )

    #expect(state.canCreate)
    #expect(state.canEdit)
    #expect(state.canReveal)
    #expect(!state.canDelete)
  }

  @Test
  func loadingDraftDisablesEditAndDeleteButKeepsReveal() {
    let state = SessionsListActionState(
      selectedSession: makeSession(scope: .project),
      isLoadingSessionDraft: true
    )

    #expect(state.canCreate)
    #expect(!state.canEdit)
    #expect(state.canReveal)
    #expect(!state.canDelete)
    #expect(state.isLoadingDraft)
  }

  private func makeSession(
    scope: WorkspaceSourceScope
  ) -> WorkspaceSessionListItem {
    WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: scope
    )
  }
}
