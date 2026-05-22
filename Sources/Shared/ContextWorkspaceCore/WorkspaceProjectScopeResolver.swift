import ContextCore
import Foundation

/// Shared resolver for deriving the writable PersonaKit root used by authoring flows.
public enum WorkspaceProjectScopeResolver {
  public static func resolveProjectScopeURL(
    _ workspaceURL: URL,
    directoryExists: @Sendable (URL) -> Bool,
    fileExists: @Sendable (URL) -> Bool = { _ in false }
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
      if fileExists(packsURL) {
        throw WorkspaceSnapshotBuildError(
          message: "PersonaKit reserved path Packs exists but is not a directory."
        )
      }

      throw MissingPersonaKitDirectoryError(projectScopeURL: projectScopeURL)
    }

    return projectScopeURL
  }
}
