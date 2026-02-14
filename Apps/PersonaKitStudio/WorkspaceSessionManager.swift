import Foundation
import PersonaKitCore

/// Editable session draft model used by Studio session editor UI.
struct WorkspaceSessionDraft: Equatable, Sendable {
  var id: String
  var personaId: String
  var directiveId: String
  var kitOverrides: [String]
}

/// Errors surfaced by Studio session editing workflows.
enum WorkspaceSessionManagerError: LocalizedError {
  case invalidSessionID
  case invalidSessionIDFormat(String)
  case invalidPersonaID(String)
  case invalidDirectiveID(String)
  case sessionAlreadyExists(String)
  case sessionNotFound(String)
  case loadFailed(String)
  case saveFailed(String)
  case deleteFailed(String)

  var errorDescription: String? {
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

/// Session CRUD contract used by `WorkspaceStore`.
protocol WorkspaceSessionManaging: Sendable {
  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>
  ) throws -> String

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws
}

/// Filesystem-backed session manager for Studio create/edit/delete workflows.
struct WorkspaceSessionManager: WorkspaceSessionManaging, Sendable {
  private let dependencies: WorkspaceSessionManagerDependencies

  init(dependencies: WorkspaceSessionManagerDependencies = .live()) {
    self.dependencies = dependencies
  }

  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
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

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>
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

    let destinationURL = sessionFileURL(
      sessionsDirectory: sessionsDirectory,
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
      kitOverrides: normalizedKitOverrides(draft.kitOverrides)
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

  func deleteSession(
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

    let projectScopeURL = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
      workspaceURL,
      directoryExists: dependencies.directoryExists
    )
    let sessionsDirectory = projectScopeURL.appendingPathComponent("Sessions")
    let fileURL = sessionFileURL(
      sessionsDirectory: sessionsDirectory,
      sessionID: normalizedSessionID
    )

    guard dependencies.fileExists(fileURL) else {
      throw WorkspaceSessionManagerError.sessionNotFound(normalizedSessionID)
    }

    do {
      try dependencies.removeItem(fileURL)
    } catch {
      throw WorkspaceSessionManagerError.deleteFailed(error.localizedDescription)
    }
  }

  private func sessionFileURL(
    sessionsDirectory: URL,
    sessionID: String
  ) -> URL {
    sessionsDirectory.appendingPathComponent("\(sessionID).session.json")
  }

  private func normalizedOptionalID(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let normalizedValue = WorkspaceEntityIDPolicy.normalized(value)

    guard !normalizedValue.isEmpty else {
      return nil
    }

    return normalizedValue
  }

  private func normalizedKitOverrides(_ values: [String]) -> [String]? {
    let normalizedValues = Array(
      Set(
        values.map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
      )
    )
    .sorted()

    if normalizedValues.isEmpty {
      return nil
    }

    return normalizedValues
  }
}

/// Injectable filesystem hooks for `WorkspaceSessionManager`.
struct WorkspaceSessionManagerDependencies {
  let directoryExists: @Sendable (URL) -> Bool
  let createDirectory: @Sendable (URL) throws -> Void
  let fileExists: @Sendable (URL) -> Bool
  let readData: @Sendable (URL) throws -> Data
  let writeData: @Sendable (Data, URL) throws -> Void
  let removeItem: @Sendable (URL) throws -> Void

  static func live() -> WorkspaceSessionManagerDependencies {
    WorkspaceSessionManagerDependencies(
      directoryExists: { url in
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      createDirectory: { url in
        let fileManager = FileManager.default

        try fileManager.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
      },
      fileExists: { url in
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.path)
      },
      readData: { url in
        try Data(contentsOf: url)
      },
      writeData: { data, url in
        try data.write(to: url, options: [.atomic])
      },
      removeItem: { url in
        let fileManager = FileManager.default
        try fileManager.removeItem(at: url)
      }
    )
  }
}

private struct SessionFileDocument: Codable, Sendable {
  let id: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]?
}
