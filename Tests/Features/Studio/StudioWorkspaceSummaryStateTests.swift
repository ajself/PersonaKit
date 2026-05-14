import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioWorkspaceSummaryStateTests {
  @Test
  func summaryReportsValidationIssuesAndDeterministicCounts() {
    let state = StudioWorkspaceSummaryState(
      workspaceURL: URL(fileURLWithPath: "/Workspace"),
      snapshot: WorkspaceSnapshot(
        sessions: [
          WorkspaceSessionListItem(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
            sourceScope: .project
          )
        ],
        personas: [
          WorkspaceListItem(
            id: "persona-a",
            displayName: "Persona A",
            fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/persona-a.persona.json"),
            sourceScope: .project
          )
        ],
        directives: [],
        kits: [],
        skills: [],
        intents: [],
        essentials: []
      ),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=1",
        issues: [
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: "session-a",
            field: "personaId",
            filePath: nil,
            message: "Missing persona.",
            severity: .error
          )
        ]
      ),
      validationErrorMessage: nil
    )

    #expect(state.workspacePath == "/Workspace")
    #expect(state.validationStatus == .issues(1))
    #expect(
      state.counts.map(\.id) == [
        "sessions",
        "personas",
        "directives",
        "kits",
        "skills",
        "essentials",
        "references",
        "intents",
      ]
    )
    #expect(state.accessibilitySummary.contains("Sessions 1"))
    #expect(state.accessibilitySummary.contains("Validation 1 issue"))
  }

  @Test
  func summaryReportsCleanValidationWhenNoIssuesRemain() {
    let state = StudioWorkspaceSummaryState(
      workspaceURL: URL(fileURLWithPath: "/Workspace"),
      snapshot: .empty,
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=0",
        issues: []
      ),
      validationErrorMessage: nil
    )

    #expect(state.validationStatus == .clean)
  }

  @Test
  func validationStatusPreservesNotRunAndFailedStates() {
    #expect(
      StudioWorkspaceValidationStatus.status(
        validation: .empty,
        validationErrorMessage: nil
      ) == .notRun
    )

    #expect(
      StudioWorkspaceValidationStatus.status(
        validation: .empty,
        validationErrorMessage: "Validation failed."
      ) == .failed
    )
  }
}
