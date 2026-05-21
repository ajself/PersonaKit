import ContextCore
import Foundation

/// Contract for building workspace-wide dependency maps used by Studio.
public protocol WorkspaceRelationshipMapBuilding: Sendable {
  func build(workspaceURL: URL) throws -> WorkspaceSessionMap
}

/// Builds deterministic workspace-wide dependency maps from PersonaKit packs.
public struct WorkspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilding, Sendable {
  private let dependencies: WorkspaceRelationshipMapBuilderDependencies
  private let globalScopeURL: URL?

  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceRelationshipMapBuilderDependencies.live()
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  public init(
    globalScopeURL: URL? = nil,
    dependencies: WorkspaceRelationshipMapBuilderDependencies
  ) {
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  public func build(workspaceURL: URL) throws -> WorkspaceSessionMap {
    let projectScopeURL = try scopeResolver().resolveProjectScopeURL(workspaceURL)
    let scopes = ScopeSet(
      projectScopeURL: projectScopeURL,
      globalScopeURL: globalScopeURL
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

    let essentialIDsByScope = loadEssentialIDsByScope(scopes: scopes)
    let sessionLoadResult = try loadSessions(scopes: scopes)
    let graph = buildGraph(
      registry: registry,
      scopes: scopes,
      sessions: sessionLoadResult.sessions,
      sessionErrors: sessionLoadResult.errors,
      essentialIDs: Set(essentialIDsByScope.keys)
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
    sessionErrors: [ResolverError],
    essentialIDs: Set<String>
  ) -> WorkspaceRelationshipMapGraph {
    var nodeStateByKey: [String: MutableMapNode] = [:]
    var edgeKeys: Set<WorkspaceSessionMapEdgeKey> = []
    var errors = sessionErrors
    var errorKeys = Set(sessionErrors.map(ResolverErrorKey.init))

    for session in sessions.sorted(by: { $0.id < $1.id }) {
      upsertNode(
        in: &nodeStateByKey,
        kind: .session,
        id: session.id,
        displayName: session.id,
        isMissing: false
      )

      let sessionNodeKey = makeNodeKey(kind: .session, id: session.id)
      let personaNodeKey = makeNodeKey(kind: .persona, id: session.personaId)
      let directiveNodeKey = makeNodeKey(kind: .directive, id: session.directiveId)
      let persona = registry.personasById[session.personaId]
      let directive = registry.directivesById[session.directiveId]

      upsertNode(
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

      upsertNode(
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

      for kitID in uniqueSorted(session.kitOverrides ?? []) {
        let kit = registry.kitsById[kitID]
        let kitNodeKey = makeNodeKey(kind: .kit, id: kitID)

        upsertNode(
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
      upsertNode(
        in: &nodeStateByKey,
        kind: .persona,
        id: persona.id,
        displayName: persona.name,
        isMissing: false
      )

      let personaNodeKey = makeNodeKey(kind: .persona, id: persona.id)

      for kitID in uniqueSorted(persona.defaultKitIds) {
        let kit = registry.kitsById[kitID]
        let kitNodeKey = makeNodeKey(kind: .kit, id: kitID)

        upsertNode(
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
      upsertNode(
        in: &nodeStateByKey,
        kind: .directive,
        id: directive.id,
        displayName: directive.title,
        isMissing: false
      )

      let directiveNodeKey = makeNodeKey(kind: .directive, id: directive.id)

      for intentID in uniqueSorted(directive.requiresIntentTemplateIds) {
        let intent = registry.intentTemplatesById[intentID]
        let intentNodeKey = makeNodeKey(kind: .intent, id: intentID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .intent,
          id: intentID,
          displayName: intent?.name ?? intentID,
          isMissing: intent == nil,
          badge: "required"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: directiveNodeKey,
            toKey: intentNodeKey,
            reason: "directive.requiresIntentTemplateIds"
          )
        )

        if intent == nil {
          appendUniqueError(
            .missingIntentId(
              sourceType: .directive,
              sourceId: directive.id,
              field: "requiresIntentTemplateIds",
              missingId: intentID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

      for skillID in uniqueSorted(directive.requiresSkillIds) {
        let skill = registry.skillsById[skillID]
        let skillNodeKey = makeNodeKey(kind: .skill, id: skillID)

        upsertNode(
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

      for referenceID in uniqueSorted(directive.referenceIds ?? []) {
        let reference = registry.referencesById[referenceID]
        let referenceNodeKey = makeNodeKey(kind: .reference, id: referenceID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .reference,
          id: referenceID,
          displayName: reference?.name ?? referenceID,
          isMissing: reference == nil
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: directiveNodeKey,
            toKey: referenceNodeKey,
            reason: "directive.referenceIds"
          )
        )

        if reference == nil {
          appendUniqueError(
            .missingReferenceId(
              sourceType: .directive,
              sourceId: directive.id,
              field: "referenceIds",
              missingId: referenceID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for kit in registry.kits.sorted(by: { $0.id < $1.id }) {
      upsertNode(
        in: &nodeStateByKey,
        kind: .kit,
        id: kit.id,
        displayName: kit.name,
        isMissing: false
      )

      let kitNodeKey = makeNodeKey(kind: .kit, id: kit.id)

      for intentID in uniqueSorted(kit.intentTemplateIds ?? []) {
        let intent = registry.intentTemplatesById[intentID]
        let intentNodeKey = makeNodeKey(kind: .intent, id: intentID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .intent,
          id: intentID,
          displayName: intent?.name ?? intentID,
          isMissing: intent == nil
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: kitNodeKey,
            toKey: intentNodeKey,
            reason: "kit.intentTemplateIds"
          )
        )

        if intent == nil {
          appendUniqueError(
            .missingIntentId(
              sourceType: .kit,
              sourceId: kit.id,
              field: "intentTemplateIds",
              missingId: intentID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

      for skillID in uniqueSorted(kit.skillIds ?? []) {
        let skill = registry.skillsById[skillID]
        let skillNodeKey = makeNodeKey(kind: .skill, id: skillID)

        upsertNode(
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

      for referenceID in uniqueSorted(kit.referenceIds ?? []) {
        let reference = registry.referencesById[referenceID]
        let referenceNodeKey = makeNodeKey(kind: .reference, id: referenceID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .reference,
          id: referenceID,
          displayName: reference?.name ?? referenceID,
          isMissing: reference == nil
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: kitNodeKey,
            toKey: referenceNodeKey,
            reason: "kit.referenceIds"
          )
        )

        if reference == nil {
          appendUniqueError(
            .missingReferenceId(
              sourceType: .kit,
              sourceId: kit.id,
              field: "referenceIds",
              missingId: referenceID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

      for essentialID in uniqueSorted(kit.essentialIds) {
        let essentialNodeKey = makeNodeKey(kind: .essential, id: essentialID)
        let exists = resolveEssential(essentialID, scopes: scopes) != nil

        upsertNode(
          in: &nodeStateByKey,
          kind: .essential,
          id: essentialID,
          displayName: essentialID,
          isMissing: !exists
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: kitNodeKey,
            toKey: essentialNodeKey,
            reason: "kit.essentialIds"
          )
        )

        if !exists {
          appendUniqueError(
            .missingEssentialFile(
              sourceType: .kit,
              sourceId: kit.id,
              field: "essentialIds",
              missingId: essentialID,
              expectedPath: PersonaKitEssentialResolver.expectedPath(for: essentialID)
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for intent in registry.intentTemplates.sorted(by: { $0.id < $1.id }) {
      upsertNode(
        in: &nodeStateByKey,
        kind: .intent,
        id: intent.id,
        displayName: intent.name,
        isMissing: false
      )

      let intentNodeKey = makeNodeKey(kind: .intent, id: intent.id)

      for skillID in uniqueSorted(intent.requiresSkillIds) {
        let skill = registry.skillsById[skillID]
        let skillNodeKey = makeNodeKey(kind: .skill, id: skillID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .skill,
          id: skillID,
          displayName: skill?.name ?? skillID,
          isMissing: skill == nil,
          badge: "required"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: intentNodeKey,
            toKey: skillNodeKey,
            reason: "intent.requiresSkillIds"
          )
        )

        if skill == nil {
          appendUniqueError(
            .missingSkillId(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "requiresSkillIds",
              missingId: skillID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

      for essentialID in uniqueSorted(intent.includesEssentialIds) {
        let essentialNodeKey = makeNodeKey(kind: .essential, id: essentialID)
        let exists = resolveEssential(essentialID, scopes: scopes) != nil

        upsertNode(
          in: &nodeStateByKey,
          kind: .essential,
          id: essentialID,
          displayName: essentialID,
          isMissing: !exists,
          badge: "required"
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: intentNodeKey,
            toKey: essentialNodeKey,
            reason: "intent.includesEssentialIds"
          )
        )

        if !exists {
          appendUniqueError(
            .missingEssentialFile(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "includesEssentialIds",
              missingId: essentialID,
              expectedPath: PersonaKitEssentialResolver.expectedPath(for: essentialID)
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }

      for referenceID in uniqueSorted(intent.referenceIds ?? []) {
        let reference = registry.referencesById[referenceID]
        let referenceNodeKey = makeNodeKey(kind: .reference, id: referenceID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .reference,
          id: referenceID,
          displayName: reference?.name ?? referenceID,
          isMissing: reference == nil
        )

        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: intentNodeKey,
            toKey: referenceNodeKey,
            reason: "intent.referenceIds"
          )
        )

        if reference == nil {
          appendUniqueError(
            .missingReferenceId(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "referenceIds",
              missingId: referenceID
            ),
            errors: &errors,
            errorKeys: &errorKeys
          )
        }
      }
    }

    for skill in registry.skills.sorted(by: { $0.id < $1.id }) {
      upsertNode(
        in: &nodeStateByKey,
        kind: .skill,
        id: skill.id,
        displayName: skill.name,
        isMissing: false
      )
    }

    for reference in registry.references.sorted(by: { $0.id < $1.id }) {
      upsertNode(
        in: &nodeStateByKey,
        kind: .reference,
        id: reference.id,
        displayName: reference.name,
        isMissing: false
      )
    }

    for essentialID in essentialIDs.sorted() {
      upsertNode(
        in: &nodeStateByKey,
        kind: .essential,
        id: essentialID,
        displayName: essentialID,
        isMissing: false
      )
    }

    let nodes = nodeStateByKey.values
      .map {
        WorkspaceSessionMapNode(
          key: $0.key,
          id: $0.id,
          displayName: $0.displayName,
          kind: $0.kind,
          isMissing: $0.isMissing,
          badges: $0.badges.sorted()
        )
      }
      .sorted { lhs, rhs in
        if lhs.kind.sortOrder != rhs.kind.sortOrder {
          return lhs.kind.sortOrder < rhs.kind.sortOrder
        }

        if lhs.id != rhs.id {
          return lhs.id < rhs.id
        }

        return lhs.key < rhs.key
      }

    let nodeByKey = Dictionary(uniqueKeysWithValues: nodes.map { ($0.key, $0) })

    let edges =
      edgeKeys
      .map {
        WorkspaceSessionMapEdge(
          fromKey: $0.fromKey,
          toKey: $0.toKey,
          reason: $0.reason
        )
      }
      .sorted { lhs, rhs in
        let lhsFrom = nodeByKey[lhs.fromKey]
        let rhsFrom = nodeByKey[rhs.fromKey]

        if lhsFrom?.kind.sortOrder != rhsFrom?.kind.sortOrder {
          return (lhsFrom?.kind.sortOrder ?? Int.max) < (rhsFrom?.kind.sortOrder ?? Int.max)
        }

        if lhsFrom?.id != rhsFrom?.id {
          return (lhsFrom?.id ?? lhs.fromKey) < (rhsFrom?.id ?? rhs.fromKey)
        }

        let lhsTo = nodeByKey[lhs.toKey]
        let rhsTo = nodeByKey[rhs.toKey]

        if lhsTo?.kind.sortOrder != rhsTo?.kind.sortOrder {
          return (lhsTo?.kind.sortOrder ?? Int.max) < (rhsTo?.kind.sortOrder ?? Int.max)
        }

        if lhsTo?.id != rhsTo?.id {
          return (lhsTo?.id ?? lhs.toKey) < (rhsTo?.id ?? rhs.toKey)
        }

        return lhs.reason < rhs.reason
      }

    return WorkspaceRelationshipMapGraph(
      nodes: nodes,
      edges: edges,
      resolutionErrors: ResolverResolutionError(errors: errors).errors
    )
  }

  private func loadEssentialIDsByScope(scopes: ScopeSet) -> [String: URL] {
    var urlsByEssentialID: [String: URL] = [:]

    for root in scopes.loadOrder {
      let essentialsDirectoryURL = root.appendingPathComponent("Packs/essentials")

      guard dependencies.directoryExists(essentialsDirectoryURL) else {
        continue
      }

      let files: [URL]

      do {
        files = try dependencies.contentsOfDirectory(essentialsDirectoryURL)
      } catch {
        continue
      }

      for fileURL in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        guard fileURL.pathExtension == "md" else {
          continue
        }

        let essentialID = fileURL.deletingPathExtension().lastPathComponent
        urlsByEssentialID[essentialID] = fileURL.standardizedFileURL
      }
    }

    return urlsByEssentialID
  }

  private func resolveEssential(
    _ essentialID: String,
    scopes: ScopeSet
  ) -> ResolvedEssential? {
    PersonaKitEssentialResolver.resolve(
      essentialID,
      scopes: scopes,
      fileExists: dependencies.fileExists
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

  private func makeNodeKey(
    kind: WorkspaceSessionMapNodeKind,
    id: String
  ) -> String {
    "\(kind.rawValue):\(id)"
  }

  private func upsertNode(
    in nodeStateByKey: inout [String: MutableMapNode],
    kind: WorkspaceSessionMapNodeKind,
    id: String,
    displayName: String,
    isMissing: Bool,
    badge: String? = nil
  ) {
    let key = makeNodeKey(kind: kind, id: id)

    if var existing = nodeStateByKey[key] {
      existing.isMissing = existing.isMissing || isMissing

      if existing.displayName == existing.id,
        displayName != id
      {
        existing.displayName = displayName
      }

      if let badge {
        existing.badges.insert(badge)
      }

      nodeStateByKey[key] = existing
      return
    }

    var badges: Set<String> = []

    if let badge {
      badges.insert(badge)
    }

    nodeStateByKey[key] = MutableMapNode(
      key: key,
      id: id,
      displayName: displayName,
      kind: kind,
      isMissing: isMissing,
      badges: badges
    )
  }

  private func scopeResolver() -> WorkspaceScopeResolver {
    WorkspaceScopeResolver(
      directoryExists: dependencies.directoryExists
    )
  }
}

/// Injectable dependencies for workspace relationship map building.
public struct WorkspaceRelationshipMapBuilderDependencies: Sendable {
  let directoryExists: @Sendable (URL) -> Bool
  let contentsOfDirectory: @Sendable (URL) throws -> [URL]
  let defaultGlobalScopeURL: @Sendable () -> URL?
  let fileExists: @Sendable (URL) -> Bool

  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    contentsOfDirectory: @escaping @Sendable (URL) throws -> [URL],
    defaultGlobalScopeURL: @escaping @Sendable () -> URL?,
    fileExists: @escaping @Sendable (URL) -> Bool
  ) {
    self.directoryExists = directoryExists
    self.contentsOfDirectory = contentsOfDirectory
    self.defaultGlobalScopeURL = defaultGlobalScopeURL
    self.fileExists = fileExists
  }

  public static func live() -> WorkspaceRelationshipMapBuilderDependencies {
    WorkspaceRelationshipMapBuilderDependencies(
      directoryExists: { url in
        WorkspaceScopeResolver.directoryExists(url, fileManager: .default)
      },
      contentsOfDirectory: { url in
        try FileManager.default.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
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

private struct MutableMapNode {
  let key: String
  let id: String
  var displayName: String
  let kind: WorkspaceSessionMapNodeKind
  var isMissing: Bool
  var badges: Set<String>
}

private struct WorkspaceSessionMapEdgeKey: Hashable {
  let fromKey: String
  let toKey: String
  let reason: String
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}
