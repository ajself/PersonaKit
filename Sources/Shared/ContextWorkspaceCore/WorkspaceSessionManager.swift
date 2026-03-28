import Foundation

/// Editable session draft model used by shared session authoring workflows.
public struct WorkspaceSessionDraft: Equatable, Sendable {
  public var id: String
  public var personaId: String
  public var directiveId: String
  public var kitOverrides: [String]

  public init(
    id: String,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) {
    self.id = id
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitOverrides = kitOverrides
  }
}

/// Errors surfaced by shared session editing workflows.
public enum WorkspaceSessionManagerError: LocalizedError {
  case invalidSessionID
  case invalidSessionIDFormat(String)
  case invalidPersonaID(String)
  case invalidDirectiveID(String)
  case invalidKitOverrideID(String)
  case sessionAlreadyExists(String)
  case sessionNotFound(String)
  case loadFailed(String)
  case saveFailed(String)
  case deleteFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidSessionID:
      return "Session id is required."
    case .invalidSessionIDFormat(let sessionID):
      return
        "Session id \"\(sessionID)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
    case .invalidPersonaID(let personaID):
      return "Persona id \"\(personaID)\" is not valid."
    case .invalidDirectiveID(let directiveID):
      return "Directive id \"\(directiveID)\" is not valid."
    case .invalidKitOverrideID(let kitID):
      return "Kit id \"\(kitID)\" is not valid."
    case .sessionAlreadyExists(let sessionID):
      return "A session with id \"\(sessionID)\" already exists."
    case .sessionNotFound(let sessionID):
      return "Session \"\(sessionID)\" was not found."
    case .loadFailed(let message):
      return "Failed to load session: \(message)"
    case .saveFailed(let message):
      return "Failed to save session: \(message)"
    case .deleteFailed(let message):
      return "Failed to delete session: \(message)"
    }
  }
}

/// Session CRUD contract used by PersonaKit authoring flows.
public protocol WorkspaceSessionManaging: Sendable {
  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft

  func destinationFileURL(
    workspaceURL: URL,
    sessionID: String
  ) throws -> URL

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws
}

public extension WorkspaceSessionManaging {
  func destinationFileURL(
    workspaceURL: URL,
    sessionID: String
  ) throws -> URL {
    throw WorkspaceSnapshotBuildError(message: "destinationFileURL is not implemented.")
  }
}

/// Filesystem-backed session manager for shared create/edit/delete workflows.
public struct WorkspaceSessionManager: WorkspaceSessionManaging, Sendable {
  private let dependencies: WorkspaceSessionManagerDependencies

  public init(dependencies: WorkspaceSessionManagerDependencies = .live()) {
    self.dependencies = dependencies
  }

  public func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    do {
      let data = try dependencies.readData(fileURL)
      let session = try JSONDecoder().decode(SessionFileDocument.self, from: data)
      let kitOverrides = normalizedKitOverrides(session.kitOverrides ?? [])

      return WorkspaceSessionDraft(
        id: session.id,
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: kitOverrides ?? []
      )
    } catch {
      throw WorkspaceSessionManagerError.loadFailed(error.localizedDescription)
    }
  }

  public func destinationFileURL(
    workspaceURL: URL,
    sessionID: String
  ) throws -> URL {
    let normalizedSessionID = WorkspaceEntityIDPolicy.normalized(sessionID)

    guard !normalizedSessionID.isEmpty else {
      throw WorkspaceSessionManagerError.invalidSessionID
    }

    guard WorkspaceEntityIDPolicy.isValid(normalizedSessionID) else {
      throw WorkspaceSessionManagerError.invalidSessionIDFormat(normalizedSessionID)
    }

    let projectScopeURL = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
      workspaceURL,
      directoryExists: dependencies.directoryExists
    )
    let sessionsDirectory = projectScopeURL.appendingPathComponent("Sessions")

    return sessionFileURL(
      sessionsDirectory: sessionsDirectory,
      sessionID: normalizedSessionID
    )
  }

  public func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    let sessionID = WorkspaceEntityIDPolicy.normalized(draft.id)

    guard !sessionID.isEmpty else {
      throw WorkspaceSessionManagerError.invalidSessionID
    }

    guard WorkspaceEntityIDPolicy.isValid(sessionID) else {
      throw WorkspaceSessionManagerError.invalidSessionIDFormat(sessionID)
    }

    guard validPersonaIDs.contains(draft.personaId) else {
      throw WorkspaceSessionManagerError.invalidPersonaID(draft.personaId)
    }

    guard validDirectiveIDs.contains(draft.directiveId) else {
      throw WorkspaceSessionManagerError.invalidDirectiveID(draft.directiveId)
    }

    let normalizedKitOverrideIDs = normalizedKitOverrides(draft.kitOverrides) ?? []

    for kitID in normalizedKitOverrideIDs {
      guard validKitIDs.contains(kitID) else {
        throw WorkspaceSessionManagerError.invalidKitOverrideID(kitID)
      }
    }

    let projectScopeURL = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
      workspaceURL,
      directoryExists: dependencies.directoryExists
    )
    let sessionsDirectory = projectScopeURL.appendingPathComponent("Sessions")

    do {
      try dependencies.createDirectory(sessionsDirectory)
    } catch {
      throw WorkspaceSessionManagerError.saveFailed(error.localizedDescription)
    }

    let destinationURL = try destinationFileURL(
      workspaceURL: workspaceURL,
      sessionID: sessionID
    )
    let normalizedOriginalID = normalizedOptionalID(originalSessionID)

    if let normalizedOriginalID,
      !WorkspaceEntityIDPolicy.isValid(normalizedOriginalID)
    {
      throw WorkspaceSessionManagerError.invalidSessionIDFormat(normalizedOriginalID)
    }

    if normalizedOriginalID == nil,
      dependencies.fileExists(destinationURL)
    {
      throw WorkspaceSessionManagerError.sessionAlreadyExists(sessionID)
    }

    if let normalizedOriginalID,
      normalizedOriginalID != sessionID
    {
      let sourceURL = sessionFileURL(
        sessionsDirectory: sessionsDirectory,
        sessionID: normalizedOriginalID
      )

      guard dependencies.fileExists(sourceURL) else {
        throw WorkspaceSessionManagerError.sessionNotFound(normalizedOriginalID)
      }

      if dependencies.fileExists(destinationURL) {
        throw WorkspaceSessionManagerError.sessionAlreadyExists(sessionID)
      }
    }

    let sessionDocument = SessionFileDocument(
      id: sessionID,
      personaId: draft.personaId,
      directiveId: draft.directiveId,
      kitOverrides: normalizedKitOverrideIDs.isEmpty ? nil : normalizedKitOverrideIDs
    )
    let data: Data

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      data = try encoder.encode(sessionDocument)
    } catch {
      throw WorkspaceSessionManagerError.saveFailed(error.localizedDescription)
    }

    do {
      try dependencies.writeData(data, destinationURL)
    } catch {
      throw WorkspaceSessionManagerError.saveFailed(error.localizedDescription)
    }

    if let normalizedOriginalID,
      normalizedOriginalID != sessionID
    {
      let sourceURL = sessionFileURL(
        sessionsDirectory: sessionsDirectory,
        sessionID: normalizedOriginalID
      )

      do {
        try dependencies.removeItem(sourceURL)
      } catch {
        let sourceRemovalError = error.localizedDescription
        let rollbackErrorMessage: String

        do {
          try dependencies.removeItem(destinationURL)
          rollbackErrorMessage = ""
        } catch {
          rollbackErrorMessage =
            " Rollback failed: \(error.localizedDescription)."
        }

        throw WorkspaceSessionManagerError.saveFailed(
          "Rename cleanup failed: \(sourceRemovalError).\(rollbackErrorMessage)"
        )
      }
    }

    return sessionID
  }

  public func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {
    let normalizedSessionID = WorkspaceEntityIDPolicy.normalized(sessionID)

    guard !normalizedSessionID.isEmpty else {
      throw WorkspaceSessionManagerError.invalidSessionID
    }

    guard WorkspaceEntityIDPolicy.isValid(normalizedSessionID) else {
      throw WorkspaceSessionManagerError.invalidSessionIDFormat(normalizedSessionID)
    }

    let destinationURL = try destinationFileURL(
      workspaceURL: workspaceURL,
      sessionID: normalizedSessionID
    )

    guard dependencies.fileExists(destinationURL) else {
      throw WorkspaceSessionManagerError.sessionNotFound(normalizedSessionID)
    }

    do {
      try dependencies.removeItem(destinationURL)
    } catch {
      throw WorkspaceSessionManagerError.deleteFailed(error.localizedDescription)
    }
  }
}

/// Injectable filesystem hooks for shared session editing.
public struct WorkspaceSessionManagerDependencies: Sendable {
  public let directoryExists: @Sendable (URL) -> Bool
  public let createDirectory: @Sendable (URL) throws -> Void
  public let fileExists: @Sendable (URL) -> Bool
  public let readData: @Sendable (URL) throws -> Data
  public let writeData: @Sendable (Data, URL) throws -> Void
  public let removeItem: @Sendable (URL) throws -> Void

  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    createDirectory: @escaping @Sendable (URL) throws -> Void,
    fileExists: @escaping @Sendable (URL) -> Bool,
    readData: @escaping @Sendable (URL) throws -> Data,
    writeData: @escaping @Sendable (Data, URL) throws -> Void,
    removeItem: @escaping @Sendable (URL) throws -> Void
  ) {
    self.directoryExists = directoryExists
    self.createDirectory = createDirectory
    self.fileExists = fileExists
    self.readData = readData
    self.writeData = writeData
    self.removeItem = removeItem
  }

  public static func live() -> WorkspaceSessionManagerDependencies {
    WorkspaceSessionManagerDependencies(
      directoryExists: { url in
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      createDirectory: { url in
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
      },
      fileExists: { url in
        FileManager.default.fileExists(atPath: url.path)
      },
      readData: { url in
        try Data(contentsOf: url)
      },
      writeData: { data, url in
        try data.write(to: url, options: [.atomic])
      },
      removeItem: { url in
        try FileManager.default.removeItem(at: url)
      }
    )
  }
}

private func normalizedOptionalID(_ value: String?) -> String? {
  guard let value else {
    return nil
  }

  let normalized = WorkspaceEntityIDPolicy.normalized(value)
  return normalized.isEmpty ? nil : normalized
}

private func normalizedKitOverrides(_ values: [String]) -> [String]? {
  let normalizedValues =
    values
    .map { WorkspaceEntityIDPolicy.normalized($0) }
    .filter { !$0.isEmpty }

  guard !normalizedValues.isEmpty else {
    return nil
  }

  return Array(Set(normalizedValues)).sorted()
}

private func sessionFileURL(
  sessionsDirectory: URL,
  sessionID: String
) -> URL {
  sessionsDirectory.appendingPathComponent("\(sessionID).session.json")
}

private struct SessionFileDocument: Codable, Sendable {
  let id: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]?
}
