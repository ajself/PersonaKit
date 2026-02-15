import Foundation

/// Locates the nearest project PersonaKit root by walking parent directories.
public struct ProjectPersonaKitLocator: Sendable {
  private let startingURL: URL

  /// Creates a locator rooted at `startingURL` or the current working directory.
  ///
  /// - Parameter startingURL: Optional starting directory override for tests.
  public init(startingURL: URL? = nil) {
    if let startingURL {
      self.startingURL = startingURL
    } else {
      self.startingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
  }

  /// Returns the nearest `/.personakit` directory from current to filesystem root.
  ///
  /// - Returns: The first matching PersonaKit directory URL, or `nil` when none exists.
  public func locate() -> URL? {
    var current = startingURL.standardizedFileURL
    var remaining = current.pathComponents.count + 1

    while remaining > 0 {
      if hasPersonaKitDirectory(at: current) {
        return current.appendingPathComponent(".personakit")
      }

      let parent = current.deletingLastPathComponent()
      if parent.path == current.path {
        return nil
      }

      current = parent
      remaining -= 1
    }

    return nil
  }

  /// Checks whether `root/.personakit` exists and is a directory.
  private func hasPersonaKitDirectory(at root: URL) -> Bool {
    let candidate = root.appendingPathComponent(".personakit")
    var isDirectory: ObjCBool = false

    return FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }
}
