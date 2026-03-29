import ContextWorkspaceCore
import Testing

@testable import StudioFeatures

struct StudioDiagnosticsNavigationResolverTests {
  @Test
  func referenceIssuesRouteToReferencesSidebar() {
    let target = StudioDiagnosticsNavigationResolver.navigationTarget(
      for: WorkspaceValidationIssue(
        entityType: .reference,
        entityId: "swift-style-guide-reference",
        field: "referenceIds",
        filePath: "Packs/references/swift-style-guide-reference.reference.json",
        message: "Missing reference id.",
        severity: .error
      )
    )

    #expect(target.sidebarItem == .references)
    #expect(target.selectedLibraryItemID == "swift-style-guide-reference")
    #expect(target.searchText == "swift-style-guide-reference")
  }

  @Test
  func referenceMarkdownIssuesInferReferenceIDFromBodyPath() {
    let target = StudioDiagnosticsNavigationResolver.navigationTarget(
      for: WorkspaceValidationIssue(
        entityType: .reference,
        entityId: nil,
        field: "body",
        filePath: "Packs/references/swiftui-style-guide-reference.md",
        message: "Missing reference body.",
        severity: .error
      )
    )

    #expect(target.sidebarItem == .references)
    #expect(target.selectedLibraryItemID == "swiftui-style-guide-reference")
    #expect(target.searchText == "swiftui-style-guide-reference")
  }
}
