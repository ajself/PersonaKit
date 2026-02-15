import Foundation

/// Locates the global PersonaKit root at `~/.personakit`.
public struct GlobalPersonaKitLocator: Sendable {
  private let homeDirectory: URL

  /// Creates a locator rooted at the provided home directory.
  ///
  /// - Parameter homeDirectory: Optional home directory override for tests.
  public init(homeDirectory: URL? = nil) {
    self.homeDirectory = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
  }

  /// Returns the global PersonaKit root if it exists and is a directory.
  ///
  /// - Returns: The standardized `~/.personakit` URL when present; otherwise `nil`.
  public func locate() -> URL? {
    let candidate = homeDirectory.appendingPathComponent(".personakit")
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }

    return candidate.standardizedFileURL
  }
}
