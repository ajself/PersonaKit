import Foundation

/// User-provided identifiers and optional kit overrides for session resolution.
struct SessionDefinition {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]?
}

/// Metadata for an essential referenced by a resolved session.
struct ResolvedEssential: Equatable {
  let id: String
  let url: URL
  let content: String?
}

/// Fully resolved PersonaKit entities for a single session.
struct ResolvedSession {
  let persona: Persona
  let directive: Directive
  let kits: [Kit]
  let essentials: [ResolvedEssential]
  let intents: [IntentTemplate]
  let skills: [Skill]
}

/// Entity categories used to attribute resolution failures.
enum ResolverEntityType: String {
  case sessionDefinition = "session"
  case persona
  case kit
  case directive
  case intentTemplate
  case skill

  /// Stable sort priority used for deterministic error ordering.
  var sortOrder: Int {
    switch self {
    case .sessionDefinition:
      return 0
    case .persona:
      return 1
    case .kit:
      return 2
    case .directive:
      return 3
    case .intentTemplate:
      return 4
    case .skill:
      return 5
    }
  }
}

/// Structured resolution failure for missing ids or files.
enum ResolverError: Error, Equatable {
  case missingPersona(field: String, id: String)
  case missingDirective(field: String, id: String)
  case missingKitId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingIntentId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingSkillId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingEssentialFile(
    sourceType: ResolverEntityType,
    sourceId: String,
    field: String,
    missingId: String,
    expectedPath: String
  )

  /// The entity type that referenced the missing dependency.
  var sourceType: ResolverEntityType {
    switch self {
    case .missingPersona:
      return .sessionDefinition
    case .missingDirective:
      return .sessionDefinition
    case .missingKitId(let sourceType, _, _, _):
      return sourceType
    case .missingIntentId(let sourceType, _, _, _):
      return sourceType
    case .missingSkillId(let sourceType, _, _, _):
      return sourceType
    case .missingEssentialFile(let sourceType, _, _, _, _):
      return sourceType
    }
  }

  /// The id of the entity that referenced the missing dependency.
  var sourceId: String {
    switch self {
    case .missingPersona:
      return "session"
    case .missingDirective:
      return "session"
    case .missingKitId(_, let sourceId, _, _):
      return sourceId
    case .missingIntentId(_, let sourceId, _, _):
      return sourceId
    case .missingSkillId(_, let sourceId, _, _):
      return sourceId
    case .missingEssentialFile(_, let sourceId, _, _, _):
      return sourceId
    }
  }

  /// The schema field that contained the missing reference.
  var field: String {
    switch self {
    case .missingPersona(let field, _):
      return field
    case .missingDirective(let field, _):
      return field
    case .missingKitId(_, _, let field, _):
      return field
    case .missingIntentId(_, _, let field, _):
      return field
    case .missingSkillId(_, _, let field, _):
      return field
    case .missingEssentialFile(_, _, let field, _, _):
      return field
    }
  }

  /// The id or value that could not be resolved.
  var missingId: String {
    switch self {
    case .missingPersona(_, let id):
      return id
    case .missingDirective(_, let id):
      return id
    case .missingKitId(_, _, _, let missingId):
      return missingId
    case .missingIntentId(_, _, _, let missingId):
      return missingId
    case .missingSkillId(_, _, _, let missingId):
      return missingId
    case .missingEssentialFile(_, _, _, let missingId, _):
      return missingId
    }
  }

  /// Human-readable error message used in CLI and MCP output.
  var message: String {
    switch self {
    case .missingPersona:
      return "Missing persona id."
    case .missingDirective:
      return "Missing directive id."
    case .missingKitId:
      return "Missing kit id."
    case .missingIntentId:
      return "Missing intent template id."
    case .missingSkillId:
      return "Missing skill id."
    case .missingEssentialFile(_, _, _, _, let expectedPath):
      return "Missing essential file at \(expectedPath)."
    }
  }
}

/// Aggregate resolution failure with deterministic sorting.
struct ResolverResolutionError: Error, Equatable {
  let errors: [ResolverError]

  /// Creates a resolution error and sorts nested errors for stable output.
  init(errors: [ResolverError]) {
    self.errors = ResolverResolutionError.sort(errors: errors)
  }

  private static func sort(errors: [ResolverError]) -> [ResolverError] {
    return errors.sorted { lhs, rhs in
      if lhs.sourceType.sortOrder != rhs.sourceType.sortOrder {
        return lhs.sourceType.sortOrder < rhs.sourceType.sortOrder
      }

      if lhs.sourceId != rhs.sourceId {
        return lhs.sourceId < rhs.sourceId
      }

      if lhs.field != rhs.field {
        return lhs.field < rhs.field
      }

      if lhs.missingId != rhs.missingId {
        return lhs.missingId < rhs.missingId
      }

      return lhs.message < rhs.message
    }
  }
}

/// Resolves a session definition into concrete PersonaKit entities.
struct Resolver {
  /// Resolves a session using explicit scope inputs.
  ///
  /// - Parameters:
  ///   - definition: Persona/directive ids and optional kit overrides.
  ///   - registry: In-memory entity registry loaded from disk.
  ///   - scopes: Scope set used to resolve essential file locations.
  ///   - fileManager: File system interface used for file existence checks.
  /// - Returns: Fully resolved session entities.
  /// - Throws: ``ResolverResolutionError`` when references cannot be resolved.
  static func resolve(
    definition: SessionDefinition,
    registry: Registry,
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> ResolvedSession {
    var errors: [ResolverError] = []

    let persona = registry.personasById[definition.personaId]
    if persona == nil {
      errors.append(.missingPersona(field: "personaId", id: definition.personaId))
    }

    let directive = registry.directivesById[definition.directiveId]
    if directive == nil {
      errors.append(.missingDirective(field: "directiveId", id: definition.directiveId))
    }

    if !errors.isEmpty {
      throw ResolverResolutionError(errors: errors)
    }

    guard let resolvedPersona = persona, let resolvedDirective = directive else {
      throw ResolverResolutionError(errors: errors)
    }

    let overrideIds = definition.kitOverrides ?? []
    for kitId in resolvedPersona.defaultKitIds {
      if registry.kitsById[kitId] == nil {
        errors.append(
          .missingKitId(
            sourceType: .persona,
            sourceId: resolvedPersona.id,
            field: "defaultKitIds",
            missingId: kitId
          )
        )
      }
    }

    for kitId in overrideIds {
      if registry.kitsById[kitId] == nil {
        errors.append(
          .missingKitId(
            sourceType: .sessionDefinition,
            sourceId: "session",
            field: "kitOverrides",
            missingId: kitId
          )
        )
      }
    }

    let kitIds = uniqueSorted(resolvedPersona.defaultKitIds + overrideIds)
    let resolvedKits = kitIds.compactMap { registry.kitsById[$0] }

    var intentIds: [String] = []
    for kit in resolvedKits {
      for intentId in kit.intentTemplateIds ?? [] {
        if registry.intentTemplatesById[intentId] == nil {
          errors.append(
            .missingIntentId(
              sourceType: .kit,
              sourceId: kit.id,
              field: "intentTemplateIds",
              missingId: intentId
            )
          )
        }
        intentIds.append(intentId)
      }
    }

    for intentId in resolvedDirective.requiresIntentTemplateIds {
      if registry.intentTemplatesById[intentId] == nil {
        errors.append(
          .missingIntentId(
            sourceType: .directive,
            sourceId: resolvedDirective.id,
            field: "requiresIntentTemplateIds",
            missingId: intentId
          )
        )
      }

      intentIds.append(intentId)
    }

    let uniqueIntentIds = uniqueSorted(intentIds)
    let resolvedIntents = uniqueIntentIds.compactMap { registry.intentTemplatesById[$0] }

    var skillIds: [String] = []
    for kit in resolvedKits {
      for skillId in kit.skillIds ?? [] {
        if registry.skillsById[skillId] == nil {
          errors.append(
            .missingSkillId(
              sourceType: .kit,
              sourceId: kit.id,
              field: "skillIds",
              missingId: skillId
            )
          )
        }
        skillIds.append(skillId)
      }
    }

    for skillId in resolvedDirective.requiresSkillIds {
      if registry.skillsById[skillId] == nil {
        errors.append(
          .missingSkillId(
            sourceType: .directive,
            sourceId: resolvedDirective.id,
            field: "requiresSkillIds",
            missingId: skillId
          )
        )
      }
      skillIds.append(skillId)
    }

    for intent in resolvedIntents {
      for skillId in intent.requiresSkillIds {
        if registry.skillsById[skillId] == nil {
          errors.append(
            .missingSkillId(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "requiresSkillIds",
              missingId: skillId
            )
          )
        }
        skillIds.append(skillId)
      }
    }

    let uniqueSkillIds = uniqueSorted(skillIds)
    let resolvedSkills = uniqueSkillIds.compactMap { registry.skillsById[$0] }

    var essentialIds: [String] = []
    for kit in resolvedKits {
      for essentialId in kit.essentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"
        if resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          errors.append(
            .missingEssentialFile(
              sourceType: .kit,
              sourceId: kit.id,
              field: "essentialIds",
              missingId: essentialId,
              expectedPath: expectedPath
            )
          )
        }
        essentialIds.append(essentialId)
      }
    }

    for intent in resolvedIntents {
      for essentialId in intent.includesEssentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"
        if resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          errors.append(
            .missingEssentialFile(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "includesEssentialIds",
              missingId: essentialId,
              expectedPath: expectedPath
            )
          )
        }
        essentialIds.append(essentialId)
      }
    }

    if !errors.isEmpty {
      throw ResolverResolutionError(errors: errors)
    }

    let uniqueEssentialIds = uniqueSorted(essentialIds)
    let resolvedEssentials = uniqueEssentialIds.compactMap { essentialId -> ResolvedEssential? in
      guard let fileURL = resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager)
      else {
        return nil
      }
      return ResolvedEssential(id: essentialId, url: fileURL, content: nil)
    }

    return ResolvedSession(
      persona: resolvedPersona,
      directive: resolvedDirective,
      kits: resolvedKits.sorted { $0.id < $1.id },
      essentials: resolvedEssentials.sorted { $0.id < $1.id },
      intents: resolvedIntents.sorted { $0.id < $1.id },
      skills: resolvedSkills.sorted { $0.id < $1.id }
    )
  }

  /// Resolves a session using a single root scope.
  ///
  /// - Parameters:
  ///   - definition: Persona/directive ids and optional kit overrides.
  ///   - registry: In-memory entity registry loaded from disk.
  ///   - rootURL: PersonaKit root directory used as project scope.
  ///   - fileManager: File system interface used for file existence checks.
  /// - Returns: Fully resolved session entities.
  /// - Throws: ``ResolverResolutionError`` when references cannot be resolved.
  static func resolve(
    definition: SessionDefinition,
    registry: Registry,
    rootURL: URL,
    fileManager: FileManager = .default
  ) throws -> ResolvedSession {
    let scopes = ScopeSet(projectScopeURL: rootURL, globalScopeURL: nil)

    return try resolve(
      definition: definition,
      registry: registry,
      scopes: scopes,
      fileManager: fileManager
    )
  }
}

/// De-duplicates and sorts ids to keep resolver output deterministic.
private func uniqueSorted(_ ids: [String]) -> [String] {
  return Set(ids).sorted()
}

/// Resolves an essential id to the first existing file in scope resolution order.
private func resolveEssentialURL(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> URL? {
  let expectedPath = "Packs/essentials/\(essentialId).md"

  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(expectedPath)

    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }

  return nil
}
