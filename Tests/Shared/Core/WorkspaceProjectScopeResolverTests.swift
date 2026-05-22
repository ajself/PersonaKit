import ContextWorkspaceCore
import Foundation
import Testing

struct WorkspaceProjectScopeResolverTests {
  @Test
  func resolveProjectScopeURLFailsWhenPacksPathIsFile() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")

    do {
      _ = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
        workspaceURL,
        directoryExists: { _ in false },
        fileExists: { url in
          url.standardizedFileURL == packsURL.standardizedFileURL
        }
      )
      Issue.record("Expected resolveProjectScopeURL to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message == "PersonaKit reserved path Packs exists but is not a directory.")
    }
  }
}
