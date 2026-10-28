import ContextCore
import ContextWorkspaceCore
import Foundation

/// Renders `personakit list <kind> --json`: a deterministic, read-only library document with per-entity provenance.
///
/// Provenance (winning scope, root-relative path, shadowed scope) comes from ``WorkspaceSnapshotBuilder`` so the
/// output agrees with Studio. Entities are the decoded schema values as ``Registry`` holds them.
enum ListJSONCommand {
  /// Document printed when no PersonaKit scope can be found. "No library here" is a state, not a fault.
  static let noLibraryDocument: String = encode(ListJSONDocument(errors: [], noLibrary: true))

  /// Renders the JSON document for `entityType` and the process exit code that goes with it.
  ///
  /// Load failures are collected across every root and returned as an error document with exit code 1.
  static func render(
    scopes: ScopeSet,
    entityType: ListEntityType,
    fileManager: FileManager = .default
  ) -> (output: String, exitCode: Int32) {
    let scopes = collapsingSharedRoot(scopes)

    guard !scopes.isEmpty else {
      return (noLibraryDocument, 0)
    }

    var errors: [ListJSONError] = []
    var sessionFiles: [WorkspaceSourceScope: [String: SessionFile]] = [:]

    for root in scopes.loadOrder {
      let scope = sourceScope(for: root, scopes: scopes)
      errors.append(contentsOf: registryErrors(root: root, scope: scope, fileManager: fileManager))

      var sessionErrors: [ListJSONError] = []
      sessionFiles[scope] = loadSessionFiles(
        root: root,
        scope: scope,
        fileManager: fileManager,
        errors: &sessionErrors
      )
      errors.append(contentsOf: sessionErrors)
    }

    guard errors.isEmpty else {
      return failure(errors)
    }

    do {
      let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
      let snapshot = try WorkspaceSnapshotBuilder(globalScopeProvider: { scopes.globalScopeURL }).build(scopes: scopes)

      return (
        encode(
          document(
            entityType: entityType,
            scopes: scopes,
            registry: registry,
            snapshot: snapshot,
            sessionFiles: sessionFiles
          )
        ),
        0
      )
    } catch let error as RegistryLoadError {
      return failure(error.errors.map { ListJSONError(registryError: $0, scope: nil) })
    } catch {
      return failure([
        ListJSONError(scope: nil, path: nil, entityType: "library", id: nil, message: error.localizedDescription)
      ])
    }
  }

  /// When project discovery walks up to the global root, both scopes name one directory. That directory is the
  /// global library, so report it once, as `global`.
  ///
  /// Uses the same canonical key as `ScopeSet.loadOrder` when it drops duplicate roots.
  private static func collapsingSharedRoot(_ scopes: ScopeSet) -> ScopeSet {
    guard let project = scopes.projectScopeURL, let global = scopes.globalScopeURL else {
      return scopes
    }

    guard canonicalKey(project) == canonicalKey(global) else {
      return scopes
    }

    return ScopeSet(projectScopeURL: nil, globalScopeURL: global)
  }

  private static func canonicalKey(_ url: URL) -> String {
    url.resolvingSymlinksInPath().standardizedFileURL.path
  }

  // MARK: - Document assembly

  private static func document(
    entityType: ListEntityType,
    scopes: ScopeSet,
    registry: Registry,
    snapshot: WorkspaceSnapshot,
    sessionFiles: [WorkspaceSourceScope: [String: SessionFile]]
  ) -> ListJSONDocument {
    let all = entityType == .all
    var document = ListJSONDocument(scopes: scopesObject(scopes))

    if all || entityType == .sessions {
      document.sessions = snapshot.sessions.compactMap { item in
        guard let session = sessionFiles[item.sourceScope]?[item.id] else {
          return nil
        }

        return ListJSONSession(
          id: item.id,
          scope: item.sourceScope,
          path: relativePath(of: item.fileURL, scope: item.sourceScope, scopes: scopes),
          shadows: item.shadowedScope,
          shadowedPath: shadowedPath(of: item.shadowedFileURL, scope: item.shadowedScope, scopes: scopes),
          personaId: item.personaId,
          directiveId: item.directiveId,
          kitOverrides: (session.kitOverrides ?? []).sorted()
        )
      }
    }

    if all || entityType == .personas {
      document.personas = entries(snapshot.personas, entities: registry.personasById, scopes: scopes)
    }

    if all || entityType == .directives {
      document.directives = entries(snapshot.directives, entities: registry.directivesById, scopes: scopes)
    }

    if all || entityType == .kits {
      document.kits = entries(snapshot.kits, entities: registry.kitsById, scopes: scopes)
    }

    if all || entityType == .skills {
      document.skills = entries(snapshot.skills, entities: registry.skillsById, scopes: scopes)
    }

    return document
  }

  private static func entries<Entity: Encodable>(
    _ items: [WorkspaceListItem],
    entities: [String: Entity],
    scopes: ScopeSet
  ) -> [ListJSONEntry<Entity>] {
    items.compactMap { item in
      guard let entity = entities[item.id] else {
        return nil
      }

      return ListJSONEntry(
        id: item.id,
        scope: item.sourceScope,
        path: relativePath(of: item.fileURL, scope: item.sourceScope, scopes: scopes),
        shadows: item.shadowedScope,
        shadowedPath: shadowedPath(of: item.shadowedFileURL, scope: item.shadowedScope, scopes: scopes),
        entity: entity
      )
    }
  }

  private static func scopesObject(_ scopes: ScopeSet) -> [String: String] {
    var object: [String: String] = [:]

    if let project = scopes.projectScopeURL {
      object["project"] = project.path
    }

    if let global = scopes.globalScopeURL {
      object["global"] = global.path
    }

    return object
  }

  // MARK: - Scope and path helpers

  private static func sourceScope(for root: URL, scopes: ScopeSet) -> WorkspaceSourceScope {
    root.standardizedFileURL == scopes.projectScopeURL ? .project : .global
  }

  private static func rootURL(for scope: WorkspaceSourceScope, scopes: ScopeSet) -> URL? {
    switch scope {
    case .project: return scopes.projectScopeURL
    case .global: return scopes.globalScopeURL
    }
  }

  private static func relativePath(of fileURL: URL, scope: WorkspaceSourceScope, scopes: ScopeSet) -> String {
    guard let root = rootURL(for: scope, scopes: scopes) else {
      return fileURL.path
    }

    return relativePath(of: fileURL, in: root) ?? fileURL.path
  }

  /// Root-relative path of the file a winner shadowed, or `nil` when nothing was shadowed.
  private static func shadowedPath(of fileURL: URL?, scope: WorkspaceSourceScope?, scopes: ScopeSet) -> String? {
    guard let fileURL, let scope else {
      return nil
    }

    return relativePath(of: fileURL, scope: scope, scopes: scopes)
  }

  private static func relativePath(of fileURL: URL, in root: URL) -> String? {
    let candidates: [(URL, URL)] = [
      (fileURL.standardizedFileURL, root.standardizedFileURL),
      (fileURL.resolvingSymlinksInPath(), root.resolvingSymlinksInPath()),
    ]

    for (file, base) in candidates {
      let baseComponents = base.pathComponents
      let fileComponents = file.pathComponents

      if fileComponents.count > baseComponents.count, fileComponents.starts(with: baseComponents) {
        return fileComponents.dropFirst(baseComponents.count).joined(separator: "/")
      }
    }

    return nil
  }

  // MARK: - Error collection

  /// One `Registry.load(root:)` per root. The registry reports every failing file in a root, so each root contributes
  /// all of its pack errors.
  private static func registryErrors(
    root: URL,
    scope: WorkspaceSourceScope,
    fileManager: FileManager
  ) -> [ListJSONError] {
    do {
      _ = try Registry.load(root: root, fileManager: fileManager)
      return []
    } catch let error as RegistryLoadError {
      return error.errors.map { ListJSONError(registryError: $0, scope: scope) }
    } catch {
      return [
        ListJSONError(
          scope: scope.rawValue,
          path: nil,
          entityType: RegistryEntityType.packsRoot.rawValue,
          id: nil,
          message: error.localizedDescription
        )
      ]
    }
  }

  /// Decodes every `Sessions/*.session.json` in one root, collecting one error per bad file.
  private static func loadSessionFiles(
    root: URL,
    scope: WorkspaceSourceScope,
    fileManager: FileManager,
    errors: inout [ListJSONError]
  ) -> [String: SessionFile] {
    let sessionsURL = PersonaKitDirectory.sessionsURL(root: root)
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: sessionsURL.path, isDirectory: &isDirectory) else {
      return [:]
    }

    guard isDirectory.boolValue else {
      errors.append(
        sessionError(
          scope: scope,
          path: "Sessions",
          id: nil,
          error: SessionFileError.discoveryPathNotDirectory("Sessions")
        )
      )
      return [:]
    }

    let files: [URL]

    do {
      files = try fileManager.personaKitDirectoryContents(at: sessionsURL)
        .filter { $0.lastPathComponent.hasSuffix(".session.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
      let message = error.localizedDescription
        .replacingOccurrences(of: sessionsURL.path, with: "Sessions")
        .replacingOccurrences(of: root.path, with: ".")
      errors.append(
        sessionError(
          scope: scope,
          path: "Sessions",
          id: nil,
          error: SessionFileError.discoveryReadFailed("Sessions", message)
        )
      )
      return [:]
    }

    var sessions: [String: SessionFile] = [:]

    for fileURL in files {
      let path = relativePath(of: fileURL, in: root) ?? "Sessions/\(fileURL.lastPathComponent)"
      let fileID = fileURL.deletingPathExtension().deletingPathExtension().lastPathComponent

      do {
        let session = try SessionFileLoader.load(fileURL: fileURL, fileManager: fileManager)
        sessions[session.id] = session
      } catch SessionFileError.idMismatch(let expected, let actual, _) {
        errors.append(
          sessionError(
            scope: scope,
            path: path,
            id: fileID,
            error: SessionFileError.idMismatch(expected, actual, path)
          )
        )
      } catch {
        errors.append(sessionError(scope: scope, path: path, id: fileID, error: error))
      }
    }

    return sessions
  }

  private static func sessionError(
    scope: WorkspaceSourceScope,
    path: String,
    id: String?,
    error: Error
  ) -> ListJSONError {
    ListJSONError(
      scope: scope.rawValue,
      path: path,
      entityType: "session",
      id: id,
      message: error.localizedDescription
    )
  }

  private static func failure(_ errors: [ListJSONError]) -> (output: String, exitCode: Int32) {
    (encode(ListJSONDocument(errors: errors.sorted())), 1)
  }

  // MARK: - Encoding

  private static let encodeFailureDocument =
    #"{"errors":[{"entityType":"library","id":null,"message":"Failed to encode JSON output.","#
    + #""path":null,"scope":null}]}"#

  private static func encode(_ document: ListJSONDocument) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]

    guard
      let data = try? encoder.encode(document),
      let text = String(bytes: data, encoding: .utf8)
    else {
      return encodeFailureDocument
    }

    return text
  }
}

// MARK: - Wire types

/// Top-level `list --json` document. Absent optionals are omitted from the output.
private struct ListJSONDocument: Encodable {
  var scopes: [String: String]?
  var sessions: [ListJSONSession]?
  var personas: [ListJSONEntry<Persona>]?
  var directives: [ListJSONEntry<Directive>]?
  var kits: [ListJSONEntry<Kit>]?
  var skills: [ListJSONEntry<Skill>]?
  var errors: [ListJSONError]?
  var noLibrary: Bool?
}

private struct ListJSONSession: Encodable {
  let id: String
  let scope: WorkspaceSourceScope
  let path: String
  let shadows: WorkspaceSourceScope?
  let shadowedPath: String?
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]

  private enum CodingKeys: String, CodingKey {
    case id, scope, path, shadows, shadowedPath, personaId, directiveId, kitOverrides
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(scope, forKey: .scope)
    try container.encode(path, forKey: .path)
    try container.encode(shadows, forKey: .shadows)
    try container.encode(shadowedPath, forKey: .shadowedPath)
    try container.encode(personaId, forKey: .personaId)
    try container.encode(directiveId, forKey: .directiveId)
    try container.encode(kitOverrides, forKey: .kitOverrides)
  }
}

private struct ListJSONEntry<Entity: Encodable>: Encodable {
  let id: String
  let scope: WorkspaceSourceScope
  let path: String
  let shadows: WorkspaceSourceScope?
  let shadowedPath: String?
  let entity: Entity

  private enum CodingKeys: String, CodingKey {
    case id, scope, path, shadows, shadowedPath, entity
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(scope, forKey: .scope)
    try container.encode(path, forKey: .path)
    try container.encode(shadows, forKey: .shadows)
    try container.encode(shadowedPath, forKey: .shadowedPath)
    try container.encode(entity, forKey: .entity)
  }
}

private struct ListJSONError: Encodable, Comparable {
  let scope: String?
  let path: String?
  let entityType: String
  let id: String?
  let message: String

  init(scope: String?, path: String?, entityType: String, id: String?, message: String) {
    self.scope = scope
    self.path = path
    self.entityType = entityType
    self.id = id
    self.message = message
  }

  init(registryError: RegistryError, scope: WorkspaceSourceScope?) {
    self.init(
      scope: scope?.rawValue,
      path: registryError.relativePath,
      entityType: registryError.entityType.rawValue,
      id: registryError.id,
      message: registryError.message
    )
  }

  private enum CodingKeys: String, CodingKey {
    case scope, path, entityType, id, message
  }

  /// Sorts by scope, path, id, then message; absent values sort first.
  static func < (lhs: ListJSONError, rhs: ListJSONError) -> Bool {
    let left = [lhs.scope ?? "", lhs.path ?? "", lhs.id ?? "", lhs.message]
    let right = [rhs.scope ?? "", rhs.path ?? "", rhs.id ?? "", rhs.message]

    return left.lexicographicallyPrecedes(right)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(scope, forKey: .scope)
    try container.encode(path, forKey: .path)
    try container.encode(entityType, forKey: .entityType)
    try container.encode(id, forKey: .id)
    try container.encode(message, forKey: .message)
  }
}
