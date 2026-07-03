import Foundation

struct SessionContractRequiredSkillReference: Sendable {
  let sourceType: ResolverEntityType
  let sourceId: String
  let field: String
  let skillId: String
}

struct SessionContractGroundingSkillDeclaration: Sendable {
  let sourceType: ResolverEntityType
  let sourceId: String
  let field: String
  let skillId: String
}

struct SessionContractComponents {
  let persona: Persona
  let directive: Directive?
  let kits: [Kit]
  let essentials: [ResolvedEssential]
  let availableGroundingSkills: [ResolvedGroundingSkill]
  let skills: [Skill]
  let requiredSkillReferences: [SessionContractRequiredSkillReference]
}

enum SessionContractComponentResolver {
  static func resolve(
    definition: SessionContractDefinition,
    registry: Registry,
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> SessionContractComponents {
    var errors: [ResolverError] = []

    let persona = registry.personasById[definition.personaId]

    if persona == nil {
      errors.append(.missingPersona(field: "personaId", id: definition.personaId))
    }

    let directive = definition.directiveId.flatMap { registry.directivesById[$0] }

    if let directiveId = definition.directiveId,
      directive == nil
    {
      errors.append(.missingDirective(field: "directiveId", id: directiveId))
    }

    guard let resolvedPersona = persona else {
      throw ResolverResolutionError(errors: errors)
    }

    let overrideIds = uniqueSorted(definition.kitOverrides ?? [])

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

    var requiredSkillReferences: [SessionContractRequiredSkillReference] = []
    var groundingSkillDeclarations: [SessionContractGroundingSkillDeclaration] = []

    // Route each attached skill by nature: grounding skills (former references —
    // trigger rules, no capabilities) become always-available grounding and skip
    // authorization; tool-awareness skills stay required and authorization-gated.
    func routeSkill(
      _ skillId: String,
      sourceType: ResolverEntityType,
      sourceId: String,
      field: String
    ) {
      guard let skill = registry.skillsById[skillId] else {
        errors.append(
          .missingSkillId(
            sourceType: sourceType,
            sourceId: sourceId,
            field: field,
            missingId: skillId
          )
        )
        return
      }

      if skill.isGrounding {
        groundingSkillDeclarations.append(
          SessionContractGroundingSkillDeclaration(
            sourceType: sourceType,
            sourceId: sourceId,
            field: field,
            skillId: skillId
          )
        )
      } else {
        requiredSkillReferences.append(
          SessionContractRequiredSkillReference(
            sourceType: sourceType,
            sourceId: sourceId,
            field: field,
            skillId: skillId
          )
        )
      }
    }

    if let resolvedDirective = directive {
      for kit in resolvedKits {
        for skillId in kit.skillIds ?? [] {
          routeSkill(skillId, sourceType: .kit, sourceId: kit.id, field: "skillIds")
        }
      }

      for skillId in resolvedDirective.requiresSkillIds {
        routeSkill(
          skillId,
          sourceType: .directive,
          sourceId: resolvedDirective.id,
          field: "requiresSkillIds"
        )
      }
    }

    var essentialIds: [String] = []

    for kit in resolvedKits {
      for essentialId in kit.essentialIds {
        let expectedPath = PersonaKitEssentialResolver.expectedPath(for: essentialId)

        if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
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

    essentialIds.append(contentsOf: SystemEssentials.injectedEssentialIds)

    if !errors.isEmpty {
      throw ResolverResolutionError(errors: errors)
    }

    let uniqueSkillIds = uniqueSorted(requiredSkillReferences.map(\.skillId))
    let resolvedSkills = uniqueSkillIds.compactMap { registry.skillsById[$0] }
    let uniqueEssentialIds = uniqueSorted(essentialIds)
    let resolvedEssentials = uniqueEssentialIds.compactMap { essentialId -> ResolvedEssential? in
      resolveReferencedEssential(
        essentialId,
        scopes: scopes,
        fileManager: fileManager
      )
    }
    let availableGroundingSkills = resolveAvailableGroundingSkills(
      declarations: groundingSkillDeclarations,
      registry: registry
    )

    return SessionContractComponents(
      persona: resolvedPersona,
      directive: directive,
      kits: resolvedKits,
      essentials: resolvedEssentials,
      availableGroundingSkills: availableGroundingSkills,
      skills: resolvedSkills,
      requiredSkillReferences: requiredSkillReferences
    )
  }
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}

private func resolveAvailableGroundingSkills(
  declarations: [SessionContractGroundingSkillDeclaration],
  registry: Registry
) -> [ResolvedGroundingSkill] {
  let groupedDeclarations = Dictionary(grouping: declarations, by: \.skillId)

  return groupedDeclarations.keys.sorted().compactMap { skillId in
    guard let skill = registry.skillsById[skillId] else {
      return nil
    }

    var seenSources: Set<String> = []
    let sources = (groupedDeclarations[skillId] ?? [])
      .map {
        ResolvedGroundingSkillSource(
          sourceType: $0.sourceType,
          sourceId: $0.sourceId,
          field: $0.field
        )
      }
      .filter { seenSources.insert("\($0.sourceType.rawValue)|\($0.sourceId)|\($0.field)").inserted }
      .sorted {
        if $0.sourceType.sortOrder != $1.sourceType.sortOrder {
          return $0.sourceType.sortOrder < $1.sourceType.sortOrder
        }

        if $0.sourceId != $1.sourceId {
          return $0.sourceId < $1.sourceId
        }

        return $0.field < $1.field
      }

    return ResolvedGroundingSkill(
      id: skill.id,
      name: skill.name,
      description: skill.description,
      triggerRules: skill.triggerRules ?? [],
      sources: sources
    )
  }
}
