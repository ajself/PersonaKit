import Foundation

/// On-disk session selection file loaded from `Sessions/*.session.json`.
public struct SessionFile: Codable, Sendable {
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
  case invalidSessionPath(String)

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
    case .invalidSessionPath(let path):
      return "Invalid session file path: \(path)"
    }
  }
}

/// Loads session files from project/global scope roots.
public struct SessionFileLoader {
  static func expectedPath(for sessionId: String) -> String {
    PersonaKitPathSafety.expectedPath(
      baseRelativePath: "Sessions",
      segment: sessionId,
      suffix: ".session.json"
    )
  }

  static func resolvedFileURL(
    root: URL,
    sessionId: String
  ) -> URL? {
    PersonaKitPathSafety.containedFileURL(
      root: root,
      baseRelativePath: "Sessions",
      segment: sessionId,
      suffix: ".session.json"
    )
  }

  static func isContainedSessionFile(
    _ fileURL: URL,
    root: URL
  ) -> Bool {
    let sessionsURL = root.appendingPathComponent("Sessions", isDirectory: true)

    return PersonaKitPathSafety.canonicalContains(sessionsURL, in: root)
      && PersonaKitPathSafety.canonicalContains(fileURL, in: sessionsURL)
  }

  /// Discovers session ids from merged scopes using resolution-order precedence.
  ///
  /// This is filename-based and does not decode session contents.
  public static func discoveredSessionIDs(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [String] {
    try discoveredSessionFileURLsByID(
      scopes: scopes,
      fileManager: fileManager
    )
    .keys
    .sorted()
  }

  /// Discovers session files from merged scopes using resolution-order precedence.
  ///
  /// Project scope wins over global scope when ids collide.
  public static func list(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [SessionFile] {
    let sessionsByID = try sessionsByID(
      scopes: scopes,
      fileManager: fileManager
    )

    return sessionsByID.keys.sorted().compactMap { id in
      sessionsByID[id]
    }
  }

  /// Discovers session files keyed by id from merged scopes using resolution-order precedence.
  public static func sessionsByID(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [String: SessionFile] {
    let sessionFileURLsByID = try discoveredSessionFileURLsByID(
      scopes: scopes,
      fileManager: fileManager
    )
    var sessionsByID: [String: SessionFile] = [:]

    for sessionID in sessionFileURLsByID.keys.sorted() {
      guard let fileURL = sessionFileURLsByID[sessionID] else {
        continue
      }

      let session = try load(
        fileURL: fileURL,
        fileManager: fileManager
      )
      sessionsByID[session.id] = session
    }

    return sessionsByID
  }

  private static func discoveredSessionFileURLsByID(
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> [String: URL] {
    var fileURLsByID: [String: URL] = [:]

    for root in scopes.resolutionOrder {
      let sessionsURL = root.appendingPathComponent("Sessions", isDirectory: true)

      guard PersonaKitPathSafety.canonicalContains(sessionsURL, in: root) else {
        continue
      }

      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: sessionsURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }

      let files = try fileManager.contentsOfDirectory(
        at: sessionsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )

      let sessionFiles =
        files
        .filter { $0.lastPathComponent.hasSuffix(".session.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      for fileURL in sessionFiles {
        guard isContainedSessionFile(fileURL, root: root) else {
          continue
        }

        let sessionID =
          fileURL
          .deletingPathExtension()
          .deletingPathExtension()
          .lastPathComponent

        guard fileURLsByID[sessionID] == nil else {
          continue
        }

        fileURLsByID[sessionID] = fileURL.standardizedFileURL
      }
    }

    return fileURLsByID
  }

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

    let relativePath = expectedPath(for: trimmedId)

    guard PersonaKitPathSafety.isSafePathSegment(trimmedId) else {
      throw SessionFileError.invalidSessionPath(relativePath)
    }

    for root in scopes.resolutionOrder {
      guard let fileURL = resolvedFileURL(root: root, sessionId: trimmedId) else {
        throw SessionFileError.invalidSessionPath(relativePath)
      }

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

    let relativePath = expectedPath(for: trimmedId)

    guard
      let fileURL = resolvedFileURL(root: root, sessionId: trimmedId)
    else {
      throw SessionFileError.invalidSessionPath(relativePath)
    }

    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw SessionFileError.notFound(trimmedId, relativePath)
    }

    return try loadSessionFile(
      fileURL: fileURL,
      sessionId: trimmedId,
      relativePath: relativePath
    )
  }

  /// Loads a session directly from a file URL and validates the filename-derived id.
  ///
  /// - Parameters:
  ///   - fileURL: Absolute or standardized URL to `*.session.json`.
  ///   - fileManager: File system interface used for existence checks.
  /// - Returns: Decoded ``SessionFile``.
  /// - Throws: ``SessionFileError`` when the file path is invalid, missing, undecodable, or its id mismatches the filename.
  public static func load(
    fileURL: URL,
    fileManager: FileManager = .default
  ) throws -> SessionFile {
    let standardized = fileURL.standardizedFileURL
    let filename = standardized.lastPathComponent

    guard filename.hasSuffix(".session.json") else {
      throw SessionFileError.invalidSessionPath(standardized.path)
    }

    let sessionId =
      standardized
      .deletingPathExtension()
      .deletingPathExtension()
      .lastPathComponent

    guard !sessionId.isEmpty else {
      throw SessionFileError.invalidSessionPath(standardized.path)
    }

    guard fileManager.fileExists(atPath: standardized.path) else {
      throw SessionFileError.notFound(sessionId, standardized.path)
    }

    return try loadSessionFile(
      fileURL: standardized,
      sessionId: sessionId,
      relativePath: standardized.path
    )
  }

  static func load(
    fileURL: URL,
    root: URL,
    fileManager: FileManager = .default
  ) throws -> SessionFile {
    let standardized = fileURL.standardizedFileURL

    guard isContainedSessionFile(standardized, root: root) else {
      throw SessionFileError.invalidSessionPath(standardized.path)
    }

    return try load(
      fileURL: standardized,
      fileManager: fileManager
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
