import Foundation

/// Source category used when normalizing a session reference.
public enum SessionReferenceSourceType: String, Codable, Sendable {
  case id
  case path
}

/// Canonicalized session reference resolved from either an id or a path.
public struct ResolvedSessionReference: Sendable {
  public let sourceRefType: SessionReferenceSourceType
  public let sessionId: String
  public let resolvedPath: String
  public let scopeRootPath: String
  public let session: SessionFile

  public init(
    sourceRefType: SessionReferenceSourceType,
    sessionId: String,
    resolvedPath: String,
    scopeRootPath: String,
    session: SessionFile
  ) {
    self.sourceRefType = sourceRefType
    self.sessionId = sessionId
    self.resolvedPath = resolvedPath
    self.scopeRootPath = scopeRootPath
    self.session = session
  }
}

/// Session-reference resolution failures surfaced to MCP and CLI callers.
public enum SessionReferenceError: LocalizedError {
  case invalidReference
  case invalidPath(String)
  case pathOutsideScopes(String)
  case notFound(String)

  public var errorDescription: String? {
    switch self {
    case .invalidReference:
      return "Session reference is required."
    case .invalidPath(let ref):
      return "Invalid session path reference: \(ref)"
    case .pathOutsideScopes(let ref):
      return "Session path is outside active PersonaKit scopes: \(ref)"
    case .notFound(let ref):
      return "Session reference not found: \(ref)"
    }
  }
}

/// Resolves a session reference supplied as either a session id or session-file path.
public enum SessionReferenceResolver {
  public static func resolve(
    scopes: ScopeSet,
    sessionRef: String,
    fileManager: FileManager = .default
  ) throws -> ResolvedSessionReference {
    let trimmedRef = sessionRef.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedRef.isEmpty else {
      throw SessionReferenceError.invalidReference
    }

    if looksLikePath(trimmedRef) {
      return try resolvePath(
        scopes: scopes,
        sessionRef: trimmedRef,
        fileManager: fileManager
      )
    }

    return try resolveID(
      scopes: scopes,
      sessionId: trimmedRef,
      fileManager: fileManager
    )
  }

  private static func resolveID(
    scopes: ScopeSet,
    sessionId: String,
    fileManager: FileManager
  ) throws -> ResolvedSessionReference {
    let session = try SessionFileLoader.load(
      scopes: scopes,
      sessionId: sessionId,
      fileManager: fileManager
    )
    let relativePath = "Sessions/\(sessionId).session.json"

    for root in scopes.resolutionOrder {
      let fileURL = root.appendingPathComponent(relativePath).standardizedFileURL
      if fileManager.fileExists(atPath: fileURL.path) {
        return ResolvedSessionReference(
          sourceRefType: .id,
          sessionId: sessionId,
          resolvedPath: fileURL.path,
          scopeRootPath: root.standardizedFileURL.path,
          session: session
        )
      }
    }

    throw SessionReferenceError.notFound(sessionId)
  }

  private static func resolvePath(
    scopes: ScopeSet,
    sessionRef: String,
    fileManager: FileManager
  ) throws -> ResolvedSessionReference {
    let candidateURLs = candidateSessionFileURLs(
      scopes: scopes,
      sessionRef: sessionRef
    )

    for candidate in candidateURLs {
      guard fileManager.fileExists(atPath: candidate.path) else {
        continue
      }

      guard let scopeRoot = matchingScopeRoot(
        fileURL: candidate,
        scopes: scopes
      ) else {
        throw SessionReferenceError.pathOutsideScopes(sessionRef)
      }

      let session = try SessionFileLoader.load(fileURL: candidate, fileManager: fileManager)
      return ResolvedSessionReference(
        sourceRefType: .path,
        sessionId: session.id,
        resolvedPath: candidate.path,
        scopeRootPath: scopeRoot.standardizedFileURL.path,
        session: session
      )
    }

    if sessionRef.hasSuffix(".session.json") || sessionRef.contains("/") || sessionRef.contains("\\") {
      throw SessionReferenceError.notFound(sessionRef)
    }

    throw SessionReferenceError.invalidPath(sessionRef)
  }

  private static func candidateSessionFileURLs(
    scopes: ScopeSet,
    sessionRef: String
  ) -> [URL] {
    let trimmed = sessionRef.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.hasPrefix("/") {
      return [URL(fileURLWithPath: trimmed).standardizedFileURL]
    }

    var candidates: [URL] = []

    for root in scopes.resolutionOrder {
      candidates.append(root.appendingPathComponent(trimmed).standardizedFileURL)
      candidates.append(root.deletingLastPathComponent().appendingPathComponent(trimmed).standardizedFileURL)
    }

    var seen: Set<String> = []
    return candidates.filter { url in
      let path = url.path
      return seen.insert(path).inserted
    }
  }

  private static func matchingScopeRoot(
    fileURL: URL,
    scopes: ScopeSet
  ) -> URL? {
    let standardizedPath = fileURL.standardizedFileURL.path

    for root in scopes.resolutionOrder {
      let rootPath = root.standardizedFileURL.path
      if standardizedPath == rootPath || standardizedPath.hasPrefix(rootPath + "/") {
        return root
      }
    }

    return nil
  }

  private static func looksLikePath(_ value: String) -> Bool {
    return
      value.contains("/") || value.contains("\\")
      || value.hasSuffix(".session.json")
      || value.hasPrefix(".")
  }
}
