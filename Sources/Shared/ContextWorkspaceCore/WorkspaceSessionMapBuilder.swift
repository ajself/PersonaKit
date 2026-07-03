import ContextCore
import Foundation

/// Builds deterministic session dependency map payloads for Studio map surfaces.
public struct WorkspaceSessionMapBuilder: WorkspaceSessionMapBuilding, Sendable {
  private let dependencies: WorkspaceSessionMapBuilderDependencies
  private let globalScope: @Sendable () -> URL?

  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceSessionMapBuilderDependencies.live()
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
    dependencies: WorkspaceSessionMapBuilderDependencies
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
    dependencies: WorkspaceSessionMapBuilderDependencies
  ) {
    self.dependencies = dependencies
    self.globalScope = globalScopeProvider
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

    let definition = SessionDefinition(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: normalizedKitOverrides(kitOverrides)
    )

    var resolutionErrors: [ResolverError] = []

    do {
      _ = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
    } catch let error as ResolverResolutionError {
      resolutionErrors = error.errors
    }

    let graph = buildGraph(
      definition: definition,
      registry: registry
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
    registry: Registry
  ) -> WorkspaceSessionMapGraph {
    var nodeStateByKey: [String: WorkspaceSessionMapMutableNode] = [:]
    var edgeKeys: Set<WorkspaceSessionMapEdgeKey> = []

    let sessionNodeKey = workspaceSessionMapNodeKey(kind: .session, id: "active-session")
    upsertWorkspaceSessionMapNode(
      in: &nodeStateByKey,
      kind: .session,
      id: "active-session",
      displayName: "Active Session",
      isMissing: false
    )

    let persona = registry.personasById[definition.personaId]
    let personaNodeKey = workspaceSessionMapNodeKey(kind: .persona, id: definition.personaId)
    upsertWorkspaceSessionMapNode(
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
    let directiveNodeKey = workspaceSessionMapNodeKey(kind: .directive, id: definition.directiveId)
    upsertWorkspaceSessionMapNode(
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

    let overrideKitIds = sortedUniqueWorkspaceSessionMapValues(definition.kitOverrides ?? [])
    let defaultKitIds = sortedUniqueWorkspaceSessionMapValues(persona?.defaultKitIds ?? [])

    for defaultKitId in defaultKitIds {
      let kit = registry.kitsById[defaultKitId]
      let kitNodeKey = workspaceSessionMapNodeKey(kind: .kit, id: defaultKitId)

      upsertWorkspaceSessionMapNode(
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
      let kitNodeKey = workspaceSessionMapNodeKey(kind: .kit, id: overrideKitId)

      upsertWorkspaceSessionMapNode(
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

    let appliedKitIds = sortedUniqueWorkspaceSessionMapValues(defaultKitIds + overrideKitIds)

    for appliedKitID in appliedKitIds {
      guard let kit = registry.kitsById[appliedKitID] else {
        continue
      }

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
      }
    }

    if let directive {
      for requiredSkillID in sortedUniqueWorkspaceSessionMapValues(directive.requiresSkillIds) {
        let skill = registry.skillsById[requiredSkillID]
        let skillNodeKey = workspaceSessionMapNodeKey(kind: .skill, id: requiredSkillID)

        upsertWorkspaceSessionMapNode(
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

    let nodes = sortedWorkspaceSessionMapNodes(from: nodeStateByKey)
    let edges = sortedWorkspaceSessionMapEdges(
      from: edgeKeys,
      nodes: nodes
    )

    return WorkspaceSessionMapGraph(
      nodes: nodes,
      edges: edges
    )
  }

  private func normalizedKitOverrides(_ input: [String]) -> [String]? {
    let normalized = sortedUniqueWorkspaceSessionMapValues(
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

  private func scopeResolver() -> WorkspaceScopeResolver {
    WorkspaceScopeResolver(
      directoryExists: dependencies.directoryExists,
      fileExists: dependencies.fileExists
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

private struct WorkspaceSessionMapGraph {
  let nodes: [WorkspaceSessionMapNode]
  let edges: [WorkspaceSessionMapEdge]
}
