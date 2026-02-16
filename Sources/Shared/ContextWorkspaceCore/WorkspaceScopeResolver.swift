import ContextCore
import Foundation

/// Resolves workspace roots used by Studio for project and global scope operations.
public struct WorkspaceScopeResolver {
  public let directoryExists: @Sendable (URL) -> Bool

  /// Creates a resolver with an injected directory existence check.
  ///
  /// - Parameter directoryExists: Closure used to check whether a URL exists as a directory.
  public init(directoryExists: @escaping @Sendable (URL) -> Bool) {
    self.directoryExists = directoryExists
  }

  /// Resolves the default global PersonaKit scope (`~/.personakit`) when present.
  public static func defaultGlobalScopeURL(fileManager: FileManager = .default) -> URL? {
    let candidate = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".personakit")

    guard directoryExists(candidate, fileManager: fileManager) else {
      return nil
    }

    return candidate.standardizedFileURL
  }

  /// Returns `true` when the provided URL exists as a directory.
  public static func directoryExists(
    _ url: URL,
    fileManager: FileManager = .default
  ) -> Bool {
    var isDirectory: ObjCBool = false

    return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  public func resolveProjectScopeURL(_ workspaceURL: URL) throws -> URL {
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
