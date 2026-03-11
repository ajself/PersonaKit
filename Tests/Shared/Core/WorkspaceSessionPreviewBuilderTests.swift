import ContextWorkspaceCore
import Foundation
import Testing

@testable import ContextCore

struct WorkspaceSessionPreviewBuilderTests {
  @Test
  func buildProducesMarkdownPreviewForValidSessionDefinition() throws {
    let projectScopeURL = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceSessionPreviewBuilder()
    let preview = try builder.build(
      projectScopeURL: projectScopeURL,
      globalScopeURL: nil,
      sessionId: "senior-swiftui-engineer_apply-style",
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    #expect(preview.contains("PersonaKit-Output-Version: 1"))
    #expect(preview.contains("# Directive"))
    #expect(preview.contains("Id: apply-style"))
  }

  @Test
  func buildMapsResolutionFailuresToWorkspaceBuildError() throws {
    let projectScopeURL = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceSessionPreviewBuilder()

    do {
      _ = try builder.build(
        projectScopeURL: projectScopeURL,
        globalScopeURL: nil,
        sessionId: "missing-session",
        personaId: "missing-persona",
        directiveId: "apply-style",
        kitOverrides: []
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Session preview resolution failed"))
      #expect(error.message.contains("missing-persona"))
    }
  }
}
