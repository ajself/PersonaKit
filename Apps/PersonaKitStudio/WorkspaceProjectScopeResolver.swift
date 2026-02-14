import Foundation
import PersonaKitCore

/// Shared resolver for deriving the project PersonaKit root used by Studio write flows.
enum WorkspaceProjectScopeResolver {
  static func resolveProjectScopeURL(
    _ workspaceURL: URL,
    directoryExists: @Sendable (URL) -> Bool
  ) throws -> URL {
    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL: URL

    if workspace.lastPathComponent == ".personakit" {
      projectScopeURL = workspace
    } else {
      projectScopeURL = workspace.appendingPathComponent(".personakit")
    }

    let packsURL = projectScopeURL.appendingPathComponent("Packs")

    guard directoryExists(packsURL) else {
      throw WorkspaceSnapshotBuildError(
        message: "Missing PersonaKit directory at \(projectScopeURL.path())."
      )
    }

    return projectScopeURL
  }
}
