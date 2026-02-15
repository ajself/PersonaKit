import Foundation

/// Resolves workspace roots used by Studio for project and global scope operations.
struct WorkspaceScopeResolver {
  let directoryExists: @Sendable (URL) -> Bool

  /// Resolves the default global PersonaKit scope (`~/.personakit`) when present.
  static func defaultGlobalScopeURL(fileManager: FileManager = .default) -> URL? {
    let candidate = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".personakit")

    guard directoryExists(candidate, fileManager: fileManager) else {
      return nil
    }

    return candidate.standardizedFileURL
  }

  /// Returns `true` when the provided URL exists as a directory.
  static func directoryExists(
    _ url: URL,
    fileManager: FileManager = .default
  ) -> Bool {
    var isDirectory: ObjCBool = false

    return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  func resolveProjectScopeURL(_ workspaceURL: URL) throws -> URL {
    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL: URL

    if workspace.lastPathComponent == ".personakit" {
      projectScopeURL = workspace
    } else {
      projectScopeURL = workspace.appendingPathComponent(".personakit")
    }

    let packsURL = PersonaKitDirectory.packsURL(root: projectScopeURL)

    guard directoryExists(packsURL) else {
      throw MissingPersonaKitDirectoryError(projectScopeURL: projectScopeURL)
    }

    return projectScopeURL
  }
}
