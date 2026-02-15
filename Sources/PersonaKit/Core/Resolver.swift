import Foundation

/// Fully resolved PersonaKit entities for a single session.
struct ResolvedSession {
  let persona: Persona
  let directive: Directive
  let kits: [Kit]
  let essentials: [ResolvedEssential]
  let intents: [IntentTemplate]
  let skills: [Skill]
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
