import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioDiagnosticsIssueGroupingTests {
  @Test
  func groupingCombinesIssuesForSameEntityAndPreservesRevealIssue() throws {
    let issues = [
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

    let groups = StudioDiagnosticsIssueGrouping.groups(for: issues)
    let group = try #require(groups.first)

    #expect(groups.count == 1)
    #expect(group.title == "Session broken-session")
    #expect(group.issueCountText == "2 issues")
    #expect(group.fieldSummary == "Fields: personaId, schema")
    #expect(group.navigationIssue.entityId == "broken-session")
    #expect(group.revealIssue?.filePath == "Packs/Sessions/broken-session.session.json")
  }

  @Test
  func groupingKeepsFileLevelIssuesSeparateWhenEntityIDIsMissing() throws {
    let issues = [
      WorkspaceValidationIssue(
        entityType: .skill,
        entityId: nil,
        field: "body",
        filePath: "Packs/skills/a.md",
        message: "Missing grounding skill body.",
        severity: .error
      ),
      WorkspaceValidationIssue(
        entityType: .skill,
        entityId: nil,
        field: "body",
        filePath: "Packs/skills/b.md",
        message: "Missing grounding skill body.",
        severity: .error
      ),
    ]

    let groups = StudioDiagnosticsIssueGrouping.groups(for: issues)

    #expect(
      groups.map(\.title) == [
        "Skill Packs/skills/a.md",
        "Skill Packs/skills/b.md",
      ]
    )
  }
}
