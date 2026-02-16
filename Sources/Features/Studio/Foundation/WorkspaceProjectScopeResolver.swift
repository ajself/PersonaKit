import ContextCore
import Foundation

/// Shared resolver for deriving the project PersonaKit root used by Studio write flows.
public enum WorkspaceProjectScopeResolver {
  public static func resolveProjectScopeURL(
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
      throw MissingPersonaKitDirectoryError(projectScopeURL: projectScopeURL)
    }

    return projectScopeURL
  }
}
