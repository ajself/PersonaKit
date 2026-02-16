import Foundation

/// Error emitted when a workspace is missing the `.personakit/Packs` directory.
public struct MissingPersonaKitDirectoryError: LocalizedError, Sendable {
  public let projectScopeURL: URL

  public init(projectScopeURL: URL) {
    self.projectScopeURL = projectScopeURL
  }

  public var errorDescription: String? {
    "Missing PersonaKit directory at \(projectScopeURL.path())."
  }
}
