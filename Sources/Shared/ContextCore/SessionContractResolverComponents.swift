import Foundation

struct SessionContractRequiredSkillReference: Sendable {
  let sourceType: ResolverEntityType
  let sourceId: String
  let field: String
  let skillId: String
}

struct SessionContractReferenceDeclaration: Sendable {
  let sourceType: ResolverEntityType
  let sourceId: String
  let field: String
  let referenceId: String
}

struct SessionContractComponents {
  let persona: Persona
  let directive: Directive?
  let kits: [Kit]
  let essentials: [ResolvedEssential]
  let availableReferences: [ResolvedReference]
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
    var referenceDeclarations: [SessionContractReferenceDeclaration] = []

    if let resolvedDirective = directive {
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

          requiredSkillReferences.append(
            SessionContractRequiredSkillReference(
              sourceType: .kit,
              sourceId: kit.id,
              field: "skillIds",
              skillId: skillId
            )
          )
        }

        for referenceId in kit.referenceIds ?? [] {
          if registry.referencesById[referenceId] == nil {
            errors.append(
              .missingReferenceId(
                sourceType: .kit,
                sourceId: kit.id,
                field: "referenceIds",
                missingId: referenceId
              )
            )
          }

          referenceDeclarations.append(
            SessionContractReferenceDeclaration(
              sourceType: .kit,
              sourceId: kit.id,
              field: "referenceIds",
              referenceId: referenceId
            )
          )
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

        requiredSkillReferences.append(
          SessionContractRequiredSkillReference(
            sourceType: .directive,
            sourceId: resolvedDirective.id,
            field: "requiresSkillIds",
            skillId: skillId
          )
        )
      }

      for referenceId in resolvedDirective.referenceIds ?? [] {
        if registry.referencesById[referenceId] == nil {
          errors.append(
            .missingReferenceId(
              sourceType: .directive,
              sourceId: resolvedDirective.id,
              field: "referenceIds",
              missingId: referenceId
            )
          )
        }

        referenceDeclarations.append(
          SessionContractReferenceDeclaration(
            sourceType: .directive,
            sourceId: resolvedDirective.id,
            field: "referenceIds",
            referenceId: referenceId
          )
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
    let availableReferences = resolveAvailableReferences(
      declarations: referenceDeclarations,
      registry: registry
    )

    return SessionContractComponents(
      persona: resolvedPersona,
      directive: directive,
      kits: resolvedKits,
      essentials: resolvedEssentials,
      availableReferences: availableReferences,
      skills: resolvedSkills,
      requiredSkillReferences: requiredSkillReferences
    )
  }
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}

private func resolveAvailableReferences(
  declarations: [SessionContractReferenceDeclaration],
  registry: Registry
) -> [ResolvedReference] {
  let groupedDeclarations = Dictionary(grouping: declarations, by: \.referenceId)

  return groupedDeclarations.keys.sorted().compactMap { referenceId in
    guard let reference = registry.referencesById[referenceId] else {
      return nil
    }

    let sources = (groupedDeclarations[referenceId] ?? [])
      .map {
        ResolvedReferenceSource(
          sourceType: $0.sourceType,
          sourceId: $0.sourceId,
          field: $0.field
        )
      }
      .sorted {
        if $0.sourceType.sortOrder != $1.sourceType.sortOrder {
          return $0.sourceType.sortOrder < $1.sourceType.sortOrder
        }

        if $0.sourceId != $1.sourceId {
          return $0.sourceId < $1.sourceId
        }

        return $0.field < $1.field
      }

    return ResolvedReference(
      id: reference.id,
      name: reference.name,
      summary: reference.summary,
      triggerRules: reference.triggerRules,
      sources: sources
    )
  }
}
