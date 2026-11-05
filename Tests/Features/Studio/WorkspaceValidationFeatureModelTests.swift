import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceValidationFeatureModelTests {
  @Test
  func missingSessionReferenceIsReportedOnce() async throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)
    try Data(
      """
      {
        "directiveId" : "apply-style",
        "id" : "broken-ref",
        "personaId" : "missing-persona"
      }
      """.utf8
    )
    .write(
      to: projectScopeURL.appendingPathComponent("Sessions/broken-ref.session.json"),
      options: [.atomic]
    )

    let sessionManager = WorkspaceSessionManager()
    let model = WorkspaceValidationFeatureModel(
      operationRunner: WorkspaceOperationRunner(
        snapshotBuilder: WorkspaceSnapshotBuilder(globalScopeProvider: { nil }),
        workspaceValidator: WorkspaceValidator(globalScopeProvider: { nil }),
        sessionManager: sessionManager,
        libraryEntityManager: WorkspaceLibraryEntityManager(),
        sessionPreviewManager: WorkspaceSessionPreviewManager(sessionManager: sessionManager),
        sessionMapBuilder: WorkspaceSessionMapBuilder(globalScopeProvider: { nil }),
        workspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilder(globalScopeProvider: { nil })
      )
    )

    model.runValidation(workspaceURL: workspaceURL)

    await waitFor {
      !model.validation.issues.isEmpty
    }

    let sessionIssues = model.validation.issues.filter {
      $0.entityType == .session && $0.entityId == "broken-ref"
    }

    #expect(sessionIssues.map(\.field) == ["personaId"])
    #expect(sessionIssues.first?.message == "Missing persona id: missing-persona")
    // Reveal in Finder needs the session's own file, even though the core error carries no path.
    #expect(
      sessionIssues.first?.filePath
        == projectScopeURL.appendingPathComponent("Sessions/broken-ref.session.json").path()
    )
  }
}
