import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioValidationReportStateTests {
  @Test
  func validWorkspaceReportShowsCoverageAndOmitsZeroCountAreas() {
    let report = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary:
          "Validation summary: personas=1 kits=1 directives=1 references=0 skills=2 essentials=1 errors=0",
        issues: []
      ),
      validationErrorMessage: nil
    )

    #expect(report.statusHeadline == "No validation issues reported")
    #expect(report.coverageLine == "Checked 1 session and 6 library/context items")
    #expect(report.checkedItemsText == "7 checked")
    #expect(report.showsCompletedStats)
    #expect(report.issueCountText == "0 issues")
    #expect(report.affectedFilesText == "0 affected files")
    #expect(
      report.areaRows.map(\.title) == [
        "Sessions",
        "Personas",
        "Directives",
        "Kits",
        "Skills",
        "Essentials",
      ]
    )
    #expect(report.omittedAreaSummary == nil)
  }

  @Test
  func invalidWorkspaceReportSummarizesAffectedEntitiesAndFiles() {
    let report = StudioValidationReportState(
      snapshot: snapshot(sessionCount: 2),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=2",
        issues: sessionIssues()
      ),
      validationErrorMessage: nil
    )

    #expect(report.statusHeadline == "2 issues need review")
    #expect(report.issueCountText == "2 issues")
    #expect(report.affectedEntitiesText == "1 affected entity")
    #expect(report.affectedFilesText == "1 affected file")
    #expect(report.areaRows.first { $0.title == "Sessions" }?.statusText == "2 issues")
    #expect(report.issueFilterOptions.map(\.title) == ["All", "Sessions"])
  }

  @Test
  func incompleteValidationStatesDoNotReportCompletedCoverage() {
    let notValidatedReport = StudioValidationReportState(
      snapshot: snapshot(),
      validation: .empty,
      validationErrorMessage: nil
    )

    #expect(notValidatedReport.statusHeadline == "Not validated")
    #expect(notValidatedReport.coverageLine == nil)
    #expect(!notValidatedReport.showsCompletedStats)

    let validatingReport = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary: "Validating workspace...",
        issues: []
      ),
      validationErrorMessage: nil
    )

    #expect(validatingReport.statusHeadline == "Validating workspace")
    #expect(validatingReport.coverageLine == "Checking workspace contents...")
    #expect(!validatingReport.showsCompletedStats)

    let failedReport = StudioValidationReportState(
      snapshot: snapshot(),
      validation: .empty,
      validationErrorMessage: "Validation crashed."
    )

    #expect(failedReport.statusHeadline == "Validation failed")
    #expect(failedReport.coverageLine == nil)
    #expect(!failedReport.showsCompletedStats)
  }

  @Test
  func issueFilteringCombinesEntityFilterAndSearchText() {
    let report = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=3",
        issues: sessionIssues() + [
          WorkspaceValidationIssue(
            entityType: .persona,
            entityId: "persona-a",
            field: "summary",
            filePath: "Packs/personas/persona-a.persona.json",
            message: "Missing summary.",
            severity: .error
          )
        ]
      ),
      validationErrorMessage: nil
    )

    #expect(
      report.visibleIssues(selectedFilterID: "session", searchText: "personaId").map(\.field)
        == ["personaId"]
    )
    #expect(
      report.visibleIssues(selectedFilterID: "persona", searchText: "summary").map(\.entityId)
        == ["persona-a"]
    )
  }

  @Test
  func disconnectedGlobalLibraryFoldsReferenceIssuesIntoBanner() {
    let report = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=2",
        issues: [referenceMissingIssue(), structuralIssue()]
      ),
      validationErrorMessage: nil,
      globalLibraryConnected: false
    )

    // The unresolved reference is folded into the banner; the structural error stays.
    #expect(report.showsGlobalLibraryBanner)
    #expect(report.suppressedGlobalReferenceIssues.map(\.field) == ["personaId"])
    #expect(report.issues.map(\.field) == ["schema"])
    #expect(report.issueCountText == "1 issue")
    #expect(report.affectedFilesText == "1 affected file")
  }

  @Test
  func disconnectedGlobalLibraryWithOnlyReferenceIssuesReadsCleanBehindBanner() {
    let report = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=1",
        issues: [referenceMissingIssue()]
      ),
      validationErrorMessage: nil,
      globalLibraryConnected: false
    )

    #expect(report.showsGlobalLibraryBanner)
    #expect(report.issues.isEmpty)
    #expect(report.statusHeadline == "No validation issues reported")
  }

  @Test
  func connectedGlobalLibraryShowsReferenceIssuesAsRealErrors() {
    let report = StudioValidationReportState(
      snapshot: snapshot(),
      validation: WorkspaceValidationSnapshot(
        summary: "Validation summary: errors=2",
        issues: [referenceMissingIssue(), structuralIssue()]
      ),
      validationErrorMessage: nil,
      globalLibraryConnected: true
    )

    #expect(!report.showsGlobalLibraryBanner)
    #expect(report.suppressedGlobalReferenceIssues.isEmpty)
    #expect(report.issues.count == 2)
    #expect(report.statusHeadline == "2 issues need review")
  }

  @Test
  func issueGroupUsesEntityAwareNavigationLabels() throws {
    let entityGroup = try #require(
      StudioDiagnosticsIssueGrouping.groups(for: sessionIssues()).first
    )

    #expect(entityGroup.navigationActionTitle == "Open Session")

    let fileGroup = try #require(
      StudioDiagnosticsIssueGrouping.groups(
        for: [
          WorkspaceValidationIssue(
            entityType: .skill,
            entityId: nil,
            field: "body",
            filePath: "Packs/skills/a.md",
            message: "Missing body.",
            severity: .error
          )
        ]
      ).first
    )

    #expect(fileGroup.navigationActionTitle == "Open File Context")
  }

  private func snapshot(
    sessionCount: Int = 1
  ) -> WorkspaceSnapshot {
    WorkspaceSnapshot(
      sessions: (0..<sessionCount).map { index in
        WorkspaceSessionListItem(
          id: "session-\(index)",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-\(index).session.json"),
          sourceScope: .project
        )
      },
      personas: [
        item(id: "persona-a", path: "Packs/personas/persona-a.persona.json")
      ],
      directives: [
        item(id: "directive-a", path: "Packs/directives/directive-a.directive.json")
      ],
      kits: [
        item(id: "kit-a", path: "Packs/kits/kit-a.kit.json")
      ],
      skills: [
        item(id: "skill-a", path: "Packs/skills/skill-a.skill.json"),
        item(id: "skill-b", path: "Packs/skills/skill-b.skill.json"),
      ],
      essentials: [
        item(id: "essential-a", path: "Packs/essentials/essential-a.md")
      ]
    )
  }

  private func item(
    id: String,
    path: String
  ) -> WorkspaceListItem {
    WorkspaceListItem(
      id: id,
      displayName: id,
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/\(path)"),
      sourceScope: .project
    )
  }

  private func referenceMissingIssue() -> WorkspaceValidationIssue {
    WorkspaceValidationIssue(
      entityType: .session,
      entityId: "session-0",
      field: "personaId",
      filePath: "Packs/Sessions/session-0.session.json",
      message: "Session personaId references missing persona id \"persona-z\".",
      severity: .error,
      referencesUnresolvedID: true
    )
  }

  private func structuralIssue() -> WorkspaceValidationIssue {
    WorkspaceValidationIssue(
      entityType: .session,
      entityId: "session-0",
      field: "schema",
      filePath: "Packs/Sessions/session-0.session.json",
      message: "Failed to decode session JSON.",
      severity: .error,
      referencesUnresolvedID: false
    )
  }

  private func sessionIssues() -> [WorkspaceValidationIssue] {
    [
      WorkspaceValidationIssue(
        entityType: .session,
        entityId: "broken-session",
        field: "schema",
        filePath: nil,
        message: "Missing persona id.",
        severity: .error
      ),
      WorkspaceValidationIssue(
        entityType: .session,
        entityId: "broken-session",
        field: "personaId",
        filePath: "Packs/Sessions/broken-session.session.json",
        message: "Session personaId references missing persona.",
        severity: .error
      ),
    ]
  }
}
