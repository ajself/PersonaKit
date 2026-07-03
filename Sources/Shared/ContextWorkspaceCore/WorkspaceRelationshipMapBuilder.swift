import ContextCore
import Foundation

/// Contract for building workspace-wide dependency maps used by Studio.
public protocol WorkspaceRelationshipMapBuilding: Sendable {
  func build(workspaceURL: URL) throws -> WorkspaceSessionMap
}

/// Builds deterministic workspace-wide dependency maps from PersonaKit packs.
public struct WorkspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilding, Sendable {
  private let dependencies: WorkspaceRelationshipMapBuilderDependencies
  private let globalScope: @Sendable () -> URL?

  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceRelationshipMapBuilderDependencies.live()
    self.init(
      globalScopeProvider: makeGlobalScopeProvider(
        explicit: globalScopeURL,
        default: dependencies.defaultGlobalScopeURL
      ),
      dependencies: dependencies
    )
  }

  public init(
    globalScopeURL: URL? = nil,
    dependencies: WorkspaceRelationshipMapBuilderDependencies
  ) {
    self.init(
      globalScopeProvider: makeGlobalScopeProvider(
        explicit: globalScopeURL,
        default: dependencies.defaultGlobalScopeURL
      ),
      dependencies: dependencies
    )
  }

  /// Reads the global scope through a late-bindable provider, resolved at build time
  /// rather than frozen at `init`.
  public init(globalScopeProvider: @escaping @Sendable () -> URL?) {
    self.init(
      globalScopeProvider: globalScopeProvider,
      dependencies: .live()
    )
  }

  /// Designated late-bindable provider init with injected dependencies.
  init(
    globalScopeProvider: @escaping @Sendable () -> URL?,
    dependencies: WorkspaceRelationshipMapBuilderDependencies
  ) {
    self.dependencies = dependencies
    self.globalScope = globalScopeProvider
  }

  public func build(workspaceURL: URL) throws -> WorkspaceSessionMap {
    let projectScopeURL = try scopeResolver().resolveProjectScopeURL(workspaceURL)
    let scopes = ScopeSet(
      projectScopeURL: projectScopeURL,
      globalScopeURL: globalScope()
    )

    let registry: Registry

    do {
      registry = try Registry.load(scopes: scopes)
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

    let sessionLoadResult = try loadSessions(scopes: scopes)
    let graph = buildGraph(
      registry: registry,
      scopes: scopes,
      sessions: sessionLoadResult.sessions,
      sessionErrors: sessionLoadResult.errors
    )

    return WorkspaceSessionMap(
      nodes: graph.nodes,
      edges: graph.edges,
      resolutionErrors: graph.resolutionErrors,
      isFullyResolved: graph.resolutionErrors.isEmpty
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

  private func loadSessions(
    scopes: ScopeSet
  ) throws -> WorkspaceRelationshipMapSessionLoadResult {
    let sessionIDs = try SessionFileLoader.discoveredSessionIDs(scopes: scopes)
    var errors: [ResolverError] = []
    var sessions: [SessionFile] = []

    for sessionID in sessionIDs {
      do {
        let session = try SessionFileLoader.load(
          scopes: scopes,
          sessionId: sessionID
        )
        sessions.append(session)
      } catch {
        errors.append(
          .invalidSession(
            sessionId: sessionID,
            expectedPath: "Sessions/\(sessionID).session.json",
            message: sessionLoadMessage(error)
          )
        )
      }
    }

    return WorkspaceRelationshipMapSessionLoadResult(
      errors: errors,
      sessions: sessions
    )
  }

  private func sessionLoadMessage(
    _ error: Error
  ) -> String {
    if let sessionError = error as? SessionFileError {
      switch sessionError {
      case .notFound(let sessionId, let expectedPath):
        return "Session file not found for \(sessionId). Expected \(expectedPath)."
      case .decodeFailed(let sessionId, _):
        return "Failed to decode session file for \(sessionId)."
      case .discoveryPathNotDirectory(let path):
        return "Session discovery path is not a directory: \(path)."
      case .discoveryReadFailed(let path, let message):
        return "Failed to read session discovery path \(path): \(message)"
      case .idMismatch(let sessionId, let actualId, let path):
        return "Session id mismatch in \(path). Expected \(sessionId), got \(actualId)."
      case .invalidSessionId:
        return "Session id is required."
      case .invalidSessionPath(let path):
        return "Invalid session file path: \(path)"
      }
    }

    return "Failed to load session."
  }

  private func buildGraph(
    registry: Registry,
    scopes: ScopeSet,
    sessions: [SessionFile],
    sessionErrors: [ResolverError]
  ) -> WorkspaceRelationshipMapGraph {
    var nodeStateByKey: [String: WorkspaceSessionMapMutableNode] = [:]
    var edgeKeys: Set<WorkspaceSessionMapEdgeKey> = []
    var errors = sessionErrors
    var errorKeys = Set(sessionErrors.map(ResolverErrorKey.init))

    for session in sessions.sorted(by: { $0.id < $1.id }) {
      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .session,
        id: session.id,
        displayName: session.id,
        isMissing: false
      )

      let sessionNodeKey = workspaceSessionMapNodeKey(kind: .session, id: session.id)
      let personaNodeKey = workspaceSessionMapNodeKey(kind: .persona, id: session.personaId)
      let directiveNodeKey = workspaceSessionMapNodeKey(kind: .directive, id: session.directiveId)
      let persona = registry.personasById[session.personaId]
      let directive = registry.directivesById[session.directiveId]

      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .persona,
        id: session.personaId,
        displayName: persona?.name ?? session.personaId,
        isMissing: persona == nil
      )

      edgeKeys.insert(
        WorkspaceSessionMapEdgeKey(
          fromKey: sessionNodeKey,
          toKey: personaNodeKey,
          reason: "session.personaId"
        )
      )

      if persona == nil {
        appendUniqueError(
          .missingPersona(
            field: "personaId",
            id: session.personaId
          ),
          errors: &errors,
          errorKeys: &errorKeys
        )
      }

      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .directive,
        id: session.directiveId,
        displayName: directive?.title ?? session.directiveId,
        isMissing: directive == nil
      )

      edgeKeys.insert(
        WorkspaceSessionMapEdgeKey(
          fromKey: sessionNodeKey,
          toKey: directiveNodeKey,
          reason: "session.directiveId"
        )
      )

      if directive == nil {
        appendUniqueError(
          .missingDirective(
            field: "directiveId",
            id: session.directiveId
          ),
          errors: &errors,
          errorKeys: &errorKeys
        )
      }

      for kitID in sortedUniqueWorkspaceSessionMapValues(session.kitOverrides ?? []) {
        let kit = registry.kitsById[kitID]
        let kitNodeKey = workspaceSessionMapNodeKey(kind: .kit, id: kitID)

        upsertWorkspaceSessionMapNode(
          in: &nodeStateByKey,
          kind: .kit,
          id: kitID,
          displayName: kit?.name ?? kitID,
          isMissing: kit == nil,
          badge: "override"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: sessionNodeKey,
            toKey: kitNodeKey,
            reason: "session.kitOverrides"
          )
        )

        if kit == nil {
          appendUniqueError(
            .missingKitId(
              sourceType: .sessionDefinition,
              sourceId: session.id,
              field: "kitOverrides",
              missingId: kitID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for persona in registry.personas.sorted(by: { $0.id < $1.id }) {
      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .persona,
        id: persona.id,
        displayName: persona.name,
        isMissing: false
      )

      let personaNodeKey = workspaceSessionMapNodeKey(kind: .persona, id: persona.id)

      for kitID in sortedUniqueWorkspaceSessionMapValues(persona.defaultKitIds) {
        let kit = registry.kitsById[kitID]
        let kitNodeKey = workspaceSessionMapNodeKey(kind: .kit, id: kitID)

        upsertWorkspaceSessionMapNode(
          in: &nodeStateByKey,
          kind: .kit,
          id: kitID,
          displayName: kit?.name ?? kitID,
          isMissing: kit == nil,
          badge: "default"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: personaNodeKey,
            toKey: kitNodeKey,
            reason: "persona.defaultKitIds"
          )
        )

        if kit == nil {
          appendUniqueError(
            .missingKitId(
              sourceType: .persona,
              sourceId: persona.id,
              field: "defaultKitIds",
              missingId: kitID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for directive in registry.directives.sorted(by: { $0.id < $1.id }) {
      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .directive,
        id: directive.id,
        displayName: directive.title,
        isMissing: false
      )

      let directiveNodeKey = workspaceSessionMapNodeKey(kind: .directive, id: directive.id)

      for skillID in sortedUniqueWorkspaceSessionMapValues(directive.requiresSkillIds) {
        let skill = registry.skillsById[skillID]
        let skillNodeKey = workspaceSessionMapNodeKey(kind: .skill, id: skillID)

        upsertWorkspaceSessionMapNode(
          in: &nodeStateByKey,
          kind: .skill,
          id: skillID,
          displayName: skill?.name ?? skillID,
          isMissing: skill == nil,
          badge: "required"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: directiveNodeKey,
            toKey: skillNodeKey,
            reason: "directive.requiresSkillIds"
          )
        )

        if skill == nil {
          appendUniqueError(
            .missingSkillId(
              sourceType: .directive,
              sourceId: directive.id,
              field: "requiresSkillIds",
              missingId: skillID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

    }

    for kit in registry.kits.sorted(by: { $0.id < $1.id }) {
      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .kit,
        id: kit.id,
        displayName: kit.name,
        isMissing: false
      )

      let kitNodeKey = workspaceSessionMapNodeKey(kind: .kit, id: kit.id)

      for skillID in sortedUniqueWorkspaceSessionMapValues(kit.skillIds ?? []) {
        let skill = registry.skillsById[skillID]
        let skillNodeKey = workspaceSessionMapNodeKey(kind: .skill, id: skillID)

        upsertWorkspaceSessionMapNode(
          in: &nodeStateByKey,
          kind: .skill,
          id: skillID,
          displayName: skill?.name ?? skillID,
          isMissing: skill == nil
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: kitNodeKey,
            toKey: skillNodeKey,
            reason: "kit.skillIds"
          )
        )

        if skill == nil {
          appendUniqueError(
            .missingSkillId(
              sourceType: .kit,
              sourceId: kit.id,
              field: "skillIds",
              missingId: skillID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for skill in registry.skills.sorted(by: { $0.id < $1.id }) {
      upsertWorkspaceSessionMapNode(
        in: &nodeStateByKey,
        kind: .skill,
        id: skill.id,
        displayName: skill.name,
        isMissing: false
      )
    }

    let nodes = sortedWorkspaceSessionMapNodes(from: nodeStateByKey)
    let edges = sortedWorkspaceSessionMapEdges(
      from: edgeKeys,
      nodes: nodes
    )

    return WorkspaceRelationshipMapGraph(
      nodes: nodes,
      edges: edges,
      resolutionErrors: ResolverResolutionError(errors: errors).errors
    )
  }

  private func appendUniqueError(
    _ error: ResolverError,
    errors: inout [ResolverError],
    errorKeys: inout Set<ResolverErrorKey>
  ) {
    let key = ResolverErrorKey(error)

    guard !errorKeys.contains(key) else {
      return
    }

    errors.append(error)
    errorKeys.insert(key)
  }

  private func scopeResolver() -> WorkspaceScopeResolver {
    WorkspaceScopeResolver(
      directoryExists: dependencies.directoryExists,
      fileExists: dependencies.fileExists
    )
  }
}

/// Injectable dependencies for workspace relationship map building.
public struct WorkspaceRelationshipMapBuilderDependencies: Sendable {
  let directoryExists: @Sendable (URL) -> Bool
  let defaultGlobalScopeURL: @Sendable () -> URL?
  let fileExists: @Sendable (URL) -> Bool

  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    defaultGlobalScopeURL: @escaping @Sendable () -> URL?,
    fileExists: @escaping @Sendable (URL) -> Bool
  ) {
    self.directoryExists = directoryExists
    self.defaultGlobalScopeURL = defaultGlobalScopeURL
    self.fileExists = fileExists
  }

  public static func live() -> WorkspaceRelationshipMapBuilderDependencies {
    WorkspaceRelationshipMapBuilderDependencies(
      directoryExists: { url in
        WorkspaceScopeResolver.directoryExists(url, fileManager: .default)
      },
      defaultGlobalScopeURL: {
        WorkspaceScopeResolver.defaultGlobalScopeURL(fileManager: .default)
      },
      fileExists: { url in
        FileManager.default.fileExists(atPath: url.path)
      }
    )
  }
}

private struct WorkspaceRelationshipMapGraph {
  let nodes: [WorkspaceSessionMapNode]
  let edges: [WorkspaceSessionMapEdge]
  let resolutionErrors: [ResolverError]
}

private struct WorkspaceRelationshipMapSessionLoadResult {
  let errors: [ResolverError]
  let sessions: [SessionFile]
}

private struct ResolverErrorKey: Hashable {
  let sourceType: ResolverEntityType
  let sourceID: String
  let field: String
  let missingID: String
  let message: String

  init(_ error: ResolverError) {
    sourceType = error.sourceType
    sourceID = error.sourceId
    field = error.field
    missingID = error.missingId
    message = error.message
  }
}
