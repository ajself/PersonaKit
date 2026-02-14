import Foundation

/// On-disk session selection file loaded from `Sessions/*.session.json`.
struct SessionFile: Codable {
  let id: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]?
}

/// Session loading failures surfaced to CLI and MCP callers.
enum SessionFileError: LocalizedError {
  case notFound(String, String)
  case decodeFailed(String, String)
  case idMismatch(String, String, String)
  case invalidSessionId

  /// Human-readable error description for session loading failures.
  var errorDescription: String? {
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
struct SessionFileLoader {
  /// Loads a session by id from the first matching root in resolution order.
  ///
  /// - Parameters:
  ///   - scopes: Scope roots used for session lookup.
  ///   - sessionId: Session id to load (trimmed before use).
  ///   - fileManager: File system interface used for existence checks.
  /// - Returns: Decoded ``SessionFile``.
  /// - Throws: ``SessionFileError`` for empty ids, missing files, decode failures, or id mismatches.
  static func load(
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
  static func load(
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
