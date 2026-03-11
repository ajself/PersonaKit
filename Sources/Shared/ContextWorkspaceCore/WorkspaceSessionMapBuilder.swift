import ContextCore
import Foundation

/// Builds deterministic session dependency map payloads for Studio map surfaces.
public struct WorkspaceSessionMapBuilder: WorkspaceSessionMapBuilding, Sendable {
  private let dependencies: WorkspaceSessionMapBuilderDependencies
  private let globalScopeURL: URL?

  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceSessionMapBuilderDependencies.live()
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  public init(
    globalScopeURL: URL? = nil,
    dependencies: WorkspaceSessionMapBuilderDependencies
  ) {
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  public func build(
    workspaceURL: URL,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> WorkspaceSessionMap {
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

    let definition = SessionDefinition(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: normalizedKitOverrides(kitOverrides)
    )

    var resolutionErrors: [ResolverError] = []
    var resolvedSession: ResolvedSession?

    do {
      resolvedSession = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
    } catch let error as ResolverResolutionError {
      resolutionErrors = error.errors
    }

    let graph = buildGraph(
      definition: definition,
      registry: registry,
      scopes: scopes,
      resolvedSession: resolvedSession
    )

    return WorkspaceSessionMap(
      nodes: graph.nodes,
      edges: graph.edges,
      resolutionErrors: resolutionErrors,
      isFullyResolved: resolutionErrors.isEmpty
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

  private func buildGraph(
    definition: SessionDefinition,
    registry: Registry,
    scopes: ScopeSet,
    resolvedSession: ResolvedSession?
  ) -> WorkspaceSessionMapGraph {
    var nodeStateByKey: [String: MutableMapNode] = [:]
    var edgeKeys: Set<WorkspaceSessionMapEdgeKey> = []
    var authoredEssentialIDs: Set<String> = []

    let sessionNodeKey = makeNodeKey(kind: .session, id: "active-session")
    upsertNode(
      in: &nodeStateByKey,
      kind: .session,
      id: "active-session",
      displayName: "Active Session",
      isMissing: false
    )

    let persona = registry.personasById[definition.personaId]
    let personaNodeKey = makeNodeKey(kind: .persona, id: definition.personaId)
    upsertNode(
      in: &nodeStateByKey,
      kind: .persona,
      id: definition.personaId,
      displayName: persona?.name ?? definition.personaId,
      isMissing: persona == nil
    )
    edgeKeys.insert(
      WorkspaceSessionMapEdgeKey(
        fromKey: sessionNodeKey,
        toKey: personaNodeKey,
        reason: "session.personaId"
      )
    )

    let directive = registry.directivesById[definition.directiveId]
    let directiveNodeKey = makeNodeKey(kind: .directive, id: definition.directiveId)
    upsertNode(
      in: &nodeStateByKey,
      kind: .directive,
      id: definition.directiveId,
      displayName: directive?.title ?? definition.directiveId,
      isMissing: directive == nil
    )
    edgeKeys.insert(
      WorkspaceSessionMapEdgeKey(
        fromKey: sessionNodeKey,
        toKey: directiveNodeKey,
        reason: "session.directiveId"
      )
    )

    let overrideKitIds = uniqueSorted(definition.kitOverrides ?? [])
    let defaultKitIds = uniqueSorted(persona?.defaultKitIds ?? [])

    for defaultKitId in defaultKitIds {
      let kit = registry.kitsById[defaultKitId]
      let kitNodeKey = makeNodeKey(kind: .kit, id: defaultKitId)

      upsertNode(
        in: &nodeStateByKey,
        kind: .kit,
        id: defaultKitId,
        displayName: kit?.name ?? defaultKitId,
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
    }

    for overrideKitId in overrideKitIds {
      let kit = registry.kitsById[overrideKitId]
      let kitNodeKey = makeNodeKey(kind: .kit, id: overrideKitId)

      upsertNode(
        in: &nodeStateByKey,
        kind: .kit,
        id: overrideKitId,
        displayName: kit?.name ?? overrideKitId,
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
    }

    let appliedKitIds = uniqueSorted(defaultKitIds + overrideKitIds)

    for appliedKitID in appliedKitIds {
      guard let kit = registry.kitsById[appliedKitID] else {
        continue
      }

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
      }

      for essentialID in uniqueSorted(kit.essentialIds) {
        authoredEssentialIDs.insert(essentialID)
        let essentialNodeKey = makeNodeKey(kind: .essential, id: essentialID)
        let essentialExists = resolveEssentialURL(essentialID, scopes: scopes) != nil

        upsertNode(
          in: &nodeStateByKey,
          kind: .essential,
          id: essentialID,
          displayName: essentialID,
          isMissing: !essentialExists
        )
        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: kitNodeKey,
            toKey: essentialNodeKey,
            reason: "kit.essentialIds"
          )
        )
      }
    }

    if let directive {
      for requiredIntentID in uniqueSorted(directive.requiresIntentTemplateIds) {
        let intent = registry.intentTemplatesById[requiredIntentID]
        let intentNodeKey = makeNodeKey(kind: .intent, id: requiredIntentID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .intent,
          id: requiredIntentID,
          displayName: intent?.name ?? requiredIntentID,
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
      }

      for requiredSkillID in uniqueSorted(directive.requiresSkillIds) {
        let skill = registry.skillsById[requiredSkillID]
        let skillNodeKey = makeNodeKey(kind: .skill, id: requiredSkillID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .skill,
          id: requiredSkillID,
          displayName: skill?.name ?? requiredSkillID,
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
      }
    }

    let intentIDs = nodeStateByKey.values
      .filter { $0.kind == .intent }
      .map(\.id)

    for intentID in uniqueSorted(intentIDs) {
      guard let intent = registry.intentTemplatesById[intentID] else {
        continue
      }

      let intentNodeKey = makeNodeKey(kind: .intent, id: intent.id)

      for requiredSkillID in uniqueSorted(intent.requiresSkillIds) {
        let skill = registry.skillsById[requiredSkillID]
        let skillNodeKey = makeNodeKey(kind: .skill, id: requiredSkillID)

        upsertNode(
          in: &nodeStateByKey,
          kind: .skill,
          id: requiredSkillID,
          displayName: skill?.name ?? requiredSkillID,
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
      }

      for essentialID in uniqueSorted(intent.includesEssentialIds) {
        authoredEssentialIDs.insert(essentialID)
        let essentialNodeKey = makeNodeKey(kind: .essential, id: essentialID)
        let essentialExists = resolveEssentialURL(essentialID, scopes: scopes) != nil

        upsertNode(
          in: &nodeStateByKey,
          kind: .essential,
          id: essentialID,
          displayName: essentialID,
          isMissing: !essentialExists,
          badge: "required"
        )
        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: intentNodeKey,
            toKey: essentialNodeKey,
            reason: "intent.includesEssentialIds"
          )
        )
      }
    }

    if let resolvedSession {
      for essential in resolvedSession.essentials
      where !authoredEssentialIDs.contains(essential.id) {
        let essentialNodeKey = makeNodeKey(kind: .essential, id: essential.id)

        upsertNode(
          in: &nodeStateByKey,
          kind: .essential,
          id: essential.id,
          displayName: essential.id,
          isMissing: false,
          badge: essential.source == .systemBuiltIn ? "runtime" : nil
        )
        edgeKeys.insert(
          WorkspaceSessionMapEdgeKey(
            fromKey: sessionNodeKey,
            toKey: essentialNodeKey,
            reason: "session.resolvedEssentials"
          )
        )
      }
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

    return WorkspaceSessionMapGraph(
      nodes: nodes,
      edges: edges
    )
  }

  private func resolveEssentialURL(
    _ essentialID: String,
    scopes: ScopeSet
  ) -> URL? {
    let expectedPath = "Packs/essentials/\(essentialID).md"

    if essentialID == "persona-activation-contract" {
      guard let activeRootURL = scopes.projectScopeURL ?? scopes.globalScopeURL else {
        return nil
      }

      let overrideURL = activeRootURL.appendingPathComponent(expectedPath)

      if dependencies.fileExists(overrideURL) {
        return overrideURL
      }

      return overrideURL
    }

    for root in scopes.resolutionOrder {
      let fileURL = root.appendingPathComponent(expectedPath)

      if dependencies.fileExists(fileURL) {
        return fileURL
      }
    }

    return nil
  }

  private func normalizedKitOverrides(_ input: [String]) -> [String]? {
    let normalized = uniqueSorted(
      input
        .map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
    )

    guard !normalized.isEmpty else {
      return nil
    }

    return normalized
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

/// Injectable dependencies for session map building.
public struct WorkspaceSessionMapBuilderDependencies: Sendable {
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

  public static func live() -> WorkspaceSessionMapBuilderDependencies {
    WorkspaceSessionMapBuilderDependencies(
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

private struct WorkspaceSessionMapGraph {
  let nodes: [WorkspaceSessionMapNode]
  let edges: [WorkspaceSessionMapEdge]
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}
