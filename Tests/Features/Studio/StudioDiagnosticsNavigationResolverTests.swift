import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioDiagnosticsNavigationResolverTests {
  @Test
  func groundingSkillIssuesRouteToSkillsSidebar() {
    let target = StudioDiagnosticsNavigationResolver.navigationTarget(
      for: WorkspaceValidationIssue(
        entityType: .skill,
        entityId: "swift-style-guide-reference",
        field: "requiresSkillIds",
        filePath: "Packs/skills/swift-style-guide-reference.skill.json",
        message: "Missing skill id.",
        severity: .error
      )
    )

    #expect(target.sidebarItem == .skills)
    #expect(target.selectedLibraryItemID == "swift-style-guide-reference")
    #expect(target.searchText == "swift-style-guide-reference")
  }

  @Test
  func groundingSkillJSONIssuesInferSkillIDFromPath() {
    let target = StudioDiagnosticsNavigationResolver.navigationTarget(
      for: WorkspaceValidationIssue(
        entityType: .skill,
        entityId: nil,
        field: "body",
        filePath: "Packs/skills/swiftui-style-guide-reference.skill.json",
        message: "Missing grounding skill body.",
        severity: .error
      )
    )

    #expect(target.sidebarItem == .skills)
    #expect(target.selectedLibraryItemID == "swiftui-style-guide-reference")
    #expect(target.searchText == "swiftui-style-guide-reference")
  }
}
