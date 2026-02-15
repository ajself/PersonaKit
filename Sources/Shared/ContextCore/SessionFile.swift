import Foundation

/// On-disk session selection file loaded from `Sessions/*.session.json`.
public struct SessionFile: Codable {
  public let id: String
  public let personaId: String
  public let directiveId: String
  public let kitOverrides: [String]?

  public init(
    id: String,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]?
  ) {
    self.id = id
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitOverrides = kitOverrides
  }
}

/// Session loading failures surfaced to CLI and MCP callers.
public enum SessionFileError: LocalizedError {
  case notFound(String, String)
  case decodeFailed(String, String)
  case idMismatch(String, String, String)
  case invalidSessionId

  /// Human-readable error description for session loading failures.
  public var errorDescription: String? {
    switch self {
    case .notFound(let sessionId, let expectedPath):
      return "Session file not found for \(sessionId). Expected \(expectedPath)."
    case .decodeFailed(let sessionId, let message):
      return "Failed to decode session file for \(sessionId): \(message)"
    case .idMismatch(let sessionId, let actualId, let path):
      return "Session id mismatch in \(path). Expected \(sessionId), got \(actualId)."
    case .invalidSessionId:
      return "Session id is required."
    }
  }
}

/// Loads session files from project/global scope roots.
public struct SessionFileLoader {
  /// Loads a session by id from the first matching root in resolution order.
  ///
  /// - Parameters:
  ///   - scopes: Scope roots used for session lookup.
  ///   - sessionId: Session id to load (trimmed before use).
  ///   - fileManager: File system interface used for existence checks.
  /// - Returns: Decoded ``SessionFile``.
  /// - Throws: ``SessionFileError`` for empty ids, missing files, decode failures, or id mismatches.
  public static func load(
    scopes: ScopeSet,
    sessionId: String,
    fileManager: FileManager = .default
  ) throws -> SessionFile {
    let trimmedId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedId.isEmpty else {
      throw SessionFileError.invalidSessionId
    }

    let relativePath = "Sessions/\(trimmedId).session.json"

    for root in scopes.resolutionOrder {
      let fileURL = root.appendingPathComponent(relativePath)

      if fileManager.fileExists(atPath: fileURL.path) {
        return try loadSessionFile(
          fileURL: fileURL,
          sessionId: trimmedId,
          relativePath: relativePath
        )
      }
    }

    throw SessionFileError.notFound(trimmedId, relativePath)
  }

  /// Loads a session by id from a single root scope.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root containing `Sessions/`.
  ///   - sessionId: Session id to load (trimmed before use).
  ///   - fileManager: File system interface used for existence checks.
  /// - Returns: Decoded ``SessionFile``.
  /// - Throws: ``SessionFileError`` for empty ids, missing files, decode failures, or id mismatches.
  public static func load(
    root: URL,
    sessionId: String,
    fileManager: FileManager = .default
  ) throws -> SessionFile {
    let trimmedId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedId.isEmpty else {
      throw SessionFileError.invalidSessionId
    }

    let relativePath = "Sessions/\(trimmedId).session.json"
    let fileURL = root.appendingPathComponent(relativePath)

    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw SessionFileError.notFound(trimmedId, relativePath)
    }

    return try loadSessionFile(
      fileURL: fileURL,
      sessionId: trimmedId,
      relativePath: relativePath
    )
  }

  /// Reads and decodes a session file, then validates id/path consistency.
  private static func loadSessionFile(
    fileURL: URL,
    sessionId: String,
    relativePath: String
  ) throws -> SessionFile {
    let data: Data

    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      throw SessionFileError.decodeFailed(sessionId, error.localizedDescription)
    }

    let session: SessionFile

    do {
      session = try JSONDecoder().decode(SessionFile.self, from: data)
    } catch {
      throw SessionFileError.decodeFailed(sessionId, error.localizedDescription)
    }

    guard session.id == sessionId else {
      throw SessionFileError.idMismatch(sessionId, session.id, relativePath)
    }

    return session
  }
}
