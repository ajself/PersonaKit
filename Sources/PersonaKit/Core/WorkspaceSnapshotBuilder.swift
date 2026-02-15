import Foundation

/// Dependency contract for snapshot loading so app code and tests can inject behavior.
public protocol WorkspaceSnapshotBuilding: Sendable {
  func build(workspaceURL: URL) throws -> WorkspaceSnapshot
}

/// Source location for an item loaded into a workspace snapshot.
public enum WorkspaceSourceScope: String, Codable, Sendable {
  case project
  case global

  /// Human-readable label shown in Studio.
  public var displayName: String {
    switch self {
    case .project:
      return "Project"
    case .global:
      return "Global"
    }
  }
}

/// Read-only list item for personas, directives, kits, skills, intents, and essentials.
public struct WorkspaceListItem: Equatable, Sendable {
  public let id: String
  public let displayName: String
  public let fileURL: URL
  public let sourceScope: WorkspaceSourceScope

  public init(
    id: String,
    displayName: String,
    fileURL: URL,
    sourceScope: WorkspaceSourceScope
  ) {
    self.id = id
    self.displayName = displayName
    self.fileURL = fileURL
    self.sourceScope = sourceScope
  }
}

/// Read-only list item for sessions.
public struct WorkspaceSessionListItem: Equatable, Sendable {
  public let id: String
  public let personaId: String
  public let directiveId: String
  public let fileURL: URL
  public let sourceScope: WorkspaceSourceScope

  public init(
    id: String,
    personaId: String,
    directiveId: String,
    fileURL: URL,
    sourceScope: WorkspaceSourceScope
  ) {
    self.id = id
    self.personaId = personaId
    self.directiveId = directiveId
    self.fileURL = fileURL
    self.sourceScope = sourceScope
  }
}

/// Aggregated read-only Studio data loaded from project/global scopes.
public struct WorkspaceSnapshot: Equatable, Sendable {
  public let sessions: [WorkspaceSessionListItem]
  public let personas: [WorkspaceListItem]
  public let directives: [WorkspaceListItem]
  public let kits: [WorkspaceListItem]
  public let skills: [WorkspaceListItem]
  public let intents: [WorkspaceListItem]
  public let essentials: [WorkspaceListItem]

  public init(
    sessions: [WorkspaceSessionListItem],
    personas: [WorkspaceListItem],
    directives: [WorkspaceListItem],
    kits: [WorkspaceListItem],
    skills: [WorkspaceListItem],
    intents: [WorkspaceListItem],
    essentials: [WorkspaceListItem]
  ) {
    self.sessions = sessions
    self.personas = personas
    self.directives = directives
    self.kits = kits
    self.skills = skills
    self.intents = intents
    self.essentials = essentials
  }

  public static let empty = WorkspaceSnapshot(
    sessions: [],
    personas: [],
    directives: [],
    kits: [],
    skills: [],
    intents: [],
    essentials: []
  )
}

/// User-facing workspace snapshot loading failure.
public struct WorkspaceSnapshotBuildError: LocalizedError, Sendable {
  public let message: String

  public init(message: String) {
    self.message = message
  }

  public var errorDescription: String? {
    message
  }
}

/// Loads deterministic, read-only Studio lists from PersonaKit project/global scopes.
public struct WorkspaceSnapshotBuilder: WorkspaceSnapshotBuilding, Sendable {
  private let dependencies: WorkspaceSnapshotBuilderDependencies
  private let globalScopeURL: URL?

  /// Creates a snapshot builder.
  ///
  /// - Parameter globalScopeURL: Optional global scope override. Defaults to `~/.personakit` if present.
  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceSnapshotBuilderDependencies.live()
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  /// Creates a snapshot builder with injected dependencies (for tests).
  init(
    globalScopeURL: URL? = nil,
    dependencies: WorkspaceSnapshotBuilderDependencies
  ) {
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  /// Builds a workspace snapshot for Studio list rendering.
  ///
  /// - Parameters:
  ///   - workspaceURL: Project workspace directory path selected by the user.
  /// - Returns: Snapshot containing merged project/global list items.
  /// - Throws: ``WorkspaceSnapshotBuildError`` when project structure is missing or reads fail.
  public func build(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try checkCancellation()

    let projectScopeURL = try scopeResolver().resolveProjectScopeURL(workspaceURL)
    let scopes = ScopeSet(projectScopeURL: projectScopeURL, globalScopeURL: globalScopeURL)

    do {
      try dependencies.validateRegistry(scopes)
    } catch let error as RegistryLoadError {
      let details = error.errors.map { Self.formatRegistryError($0) }.joined(separator: " ")
      throw WorkspaceSnapshotBuildError(
        message: "Failed to load workspace registry. \(details)"
      )
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to load workspace registry: \(error.localizedDescription)"
      )
    }

    return WorkspaceSnapshot(
      sessions: try loadSessionItems(scopes: scopes),
      personas: try loadEntityItems(scopes: scopes, type: Persona.self),
      directives: try loadEntityItems(scopes: scopes, type: Directive.self),
      kits: try loadEntityItems(scopes: scopes, type: Kit.self),
      skills: try loadEntityItems(scopes: scopes, type: Skill.self),
      intents: try loadEntityItems(scopes: scopes, type: IntentTemplate.self),
      essentials: try loadEssentialItems(scopes: scopes)
    )
  }

  private static func formatRegistryError(_ error: RegistryError) -> String {
    var parts: [String] = [error.entityType.rawValue]

    if let id = error.id {
      parts.append(id)
    }

    if let relativePath = error.relativePath {
      parts.append(relativePath)
    }

    parts.append(error.message)
    return parts.joined(separator: " ")
  }

  private func loadSessionItems(
    scopes: ScopeSet
  ) throws -> [WorkspaceSessionListItem] {
    var recordsByID: [String: WorkspaceSessionListItem] = [:]
    let decoder = JSONDecoder()

    for root in scopes.loadOrder {
      try checkCancellation()

      let sessionsURL = PersonaKitDirectory.sessionsURL(root: root)
      let files = try listFiles(
        in: sessionsURL,
        pathSuffix: ".session.json"
      )
      let sourceScope = sourceScope(for: root, scopes: scopes)

      for fileURL in files {
        try checkCancellation()

        let data = try readData(fileURL)
        let session = try decode(data: data, as: SessionFile.self, fileURL: fileURL, decoder: decoder)

        recordsByID[session.id] = WorkspaceSessionListItem(
          id: session.id,
          personaId: session.personaId,
          directiveId: session.directiveId,
          fileURL: fileURL.standardizedFileURL,
          sourceScope: sourceScope
        )
      }
    }

    return recordsByID.keys.sorted().compactMap { recordsByID[$0] }
  }

  private func loadEssentialItems(
    scopes: ScopeSet
  ) throws -> [WorkspaceListItem] {
    var recordsByID: [String: WorkspaceListItem] = [:]

    for root in scopes.loadOrder {
      try checkCancellation()

      let essentialsURL = root.appendingPathComponent("Packs/essentials")
      let files = try listFiles(
        in: essentialsURL,
        pathSuffix: ".md"
      )
      let sourceScope = sourceScope(for: root, scopes: scopes)

      for fileURL in files {
        try checkCancellation()

        let id = fileURL.deletingPathExtension().lastPathComponent
        recordsByID[id] = WorkspaceListItem(
          id: id,
          displayName: id,
          fileURL: fileURL.standardizedFileURL,
          sourceScope: sourceScope
        )
      }
    }

    return recordsByID.keys.sorted().compactMap { recordsByID[$0] }
  }

  private func loadEntityItems<T: WorkspaceEntityDocument>(
    scopes: ScopeSet,
    type: T.Type
  ) throws -> [WorkspaceListItem] {
    var recordsByID: [String: WorkspaceListItem] = [:]
    let decoder = JSONDecoder()

    for root in scopes.loadOrder {
      try checkCancellation()

      let directoryURL = root.appendingPathComponent("Packs/\(T.directoryName)")
      let files = try listFiles(
        in: directoryURL,
        pathSuffix: T.fileSuffix
      )
      let sourceScope = sourceScope(for: root, scopes: scopes)

      for fileURL in files {
        try checkCancellation()

        let data = try readData(fileURL)
        let entity = try decode(data: data, as: T.self, fileURL: fileURL, decoder: decoder)

        recordsByID[entity.id] = WorkspaceListItem(
          id: entity.id,
          displayName: entity.workspaceDisplayName,
          fileURL: fileURL.standardizedFileURL,
          sourceScope: sourceScope
        )
      }
    }

    return recordsByID.keys.sorted().compactMap { recordsByID[$0] }
  }

  private func listFiles(
    in directoryURL: URL,
    pathSuffix: String
  ) throws -> [URL] {
    try checkCancellation()

    guard dependencies.directoryExists(directoryURL) else {
      return []
    }

    do {
      return try dependencies.contentsOfDirectory(directoryURL)
        .filter { $0.lastPathComponent.hasSuffix(pathSuffix) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to read directory \(directoryURL.path()): \(error.localizedDescription)"
      )
    }
  }

  private func readData(_ fileURL: URL) throws -> Data {
    do {
      return try dependencies.readData(fileURL)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to read file \(fileURL.path()): \(error.localizedDescription)"
      )
    }
  }

  private func decode<T: Decodable>(
    data: Data,
    as type: T.Type,
    fileURL: URL,
    decoder: JSONDecoder
  ) throws -> T {
    do {
      return try decoder.decode(type, from: data)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to decode \(fileURL.path()): \(error.localizedDescription)"
      )
    }
  }

  private func sourceScope(
    for root: URL,
    scopes: ScopeSet
  ) -> WorkspaceSourceScope {
    if root.standardizedFileURL == scopes.projectScopeURL {
      return .project
    }

    return .global
  }

  private func checkCancellation() throws {
    if Task.isCancelled {
      throw CancellationError()
    }
  }

  private func scopeResolver() -> WorkspaceScopeResolver {
    WorkspaceScopeResolver(
      directoryExists: dependencies.directoryExists
    )
  }
}

/// Injectable IO and validation hooks for snapshot builder behavior.
struct WorkspaceSnapshotBuilderDependencies {
  let directoryExists: @Sendable (URL) -> Bool
  let contentsOfDirectory: @Sendable (URL) throws -> [URL]
  let readData: @Sendable (URL) throws -> Data
  let defaultGlobalScopeURL: @Sendable () -> URL?
  let validateRegistry: @Sendable (ScopeSet) throws -> Void

  /// Live filesystem-backed dependency set used by default builder construction.
  static func live() -> WorkspaceSnapshotBuilderDependencies {
    WorkspaceSnapshotBuilderDependencies(
      directoryExists: { url in
        WorkspaceScopeResolver.directoryExists(
          url,
          fileManager: .default
        )
      },
      contentsOfDirectory: { url in
        let fileManager = FileManager.default

        return try fileManager.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      },
      readData: { url in
        try Data(contentsOf: url)
      },
      defaultGlobalScopeURL: {
        WorkspaceScopeResolver.defaultGlobalScopeURL(fileManager: .default)
      },
      validateRegistry: { scopes in
        _ = try Registry.load(scopes: scopes, fileManager: .default)
      }
    )
  }
}

private protocol WorkspaceEntityDocument: Decodable {
  static var directoryName: String { get }
  static var fileSuffix: String { get }

  var id: String { get }
  var workspaceDisplayName: String { get }
}

extension Persona: WorkspaceEntityDocument {
  static let directoryName = "personas"
  static let fileSuffix = ".persona.json"

  var workspaceDisplayName: String {
    name
  }
}

extension Directive: WorkspaceEntityDocument {
  static let directoryName = "directives"
  static let fileSuffix = ".directive.json"

  var workspaceDisplayName: String {
    title
  }
}

extension Kit: WorkspaceEntityDocument {
  static let directoryName = "kits"
  static let fileSuffix = ".kit.json"

  var workspaceDisplayName: String {
    name
  }
}

extension Skill: WorkspaceEntityDocument {
  static let directoryName = "skills"
  static let fileSuffix = ".skill.json"

  var workspaceDisplayName: String {
    name
  }
}

extension IntentTemplate: WorkspaceEntityDocument {
  static let directoryName = "intents"
  static let fileSuffix = ".intent.json"

  var workspaceDisplayName: String {
    name
  }
}
