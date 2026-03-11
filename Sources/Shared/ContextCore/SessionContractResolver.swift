import Foundation

/// Optional session contract selection used by contract resolution surfaces.
public struct SessionContractDefinition: Sendable {
  public let personaId: String
  public let directiveId: String?
  public let kitOverrides: [String]?

  public init(
    personaId: String,
    directiveId: String?,
    kitOverrides: [String]?
  ) {
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitOverrides = kitOverrides
  }
}

/// Deterministic skill-authorization payload derived from a resolved contract.
public struct ResolvedSkillAuthorization: Codable, Equatable, Sendable {
  public let allowedSkillIds: [String]
  public let forbiddenSkillIds: [String]
  public let conflictingPersonaSkillIds: [String]
  public let authorizedSkillIds: [String]
  public let requiredSkillIds: [String]
  public let unauthorizedRequiredSkillIds: [String]
  public let requestedSkillIds: [String]
  public let undeclaredRequestedSkillIds: [String]
  public let unauthorizedRequestedSkillIds: [String]
  public let isAuthorized: Bool
  public let failureReasons: [String]

  public init(
    allowedSkillIds: [String],
    forbiddenSkillIds: [String],
    conflictingPersonaSkillIds: [String],
    authorizedSkillIds: [String],
    requiredSkillIds: [String],
    unauthorizedRequiredSkillIds: [String],
    requestedSkillIds: [String],
    undeclaredRequestedSkillIds: [String],
    unauthorizedRequestedSkillIds: [String],
    isAuthorized: Bool,
    failureReasons: [String]
  ) {
    self.allowedSkillIds = allowedSkillIds
    self.forbiddenSkillIds = forbiddenSkillIds
    self.conflictingPersonaSkillIds = conflictingPersonaSkillIds
    self.authorizedSkillIds = authorizedSkillIds
    self.requiredSkillIds = requiredSkillIds
    self.unauthorizedRequiredSkillIds = unauthorizedRequiredSkillIds
    self.requestedSkillIds = requestedSkillIds
    self.undeclaredRequestedSkillIds = undeclaredRequestedSkillIds
    self.unauthorizedRequestedSkillIds = unauthorizedRequestedSkillIds
    self.isAuthorized = isAuthorized
    self.failureReasons = failureReasons
  }
}

/// Fully resolved contract inputs plus derived authorization status.
public struct SessionContractResult: Sendable {
  public let sessionId: String?
  public let persona: Persona
  public let directive: Directive?
  public let kits: [Kit]
  public let essentials: [ResolvedEssential]
  public let intents: [IntentTemplate]
  public let skills: [Skill]
  public let injectedContractIds: [String]
  public let skillAuthorization: ResolvedSkillAuthorization
  public let authorizationErrors: [ResolverError]

  public init(
    sessionId: String?,
    persona: Persona,
    directive: Directive?,
    kits: [Kit],
    essentials: [ResolvedEssential],
    intents: [IntentTemplate],
    skills: [Skill],
    injectedContractIds: [String],
    skillAuthorization: ResolvedSkillAuthorization,
    authorizationErrors: [ResolverError]
  ) {
    self.sessionId = sessionId
    self.persona = persona
    self.directive = directive
    self.kits = kits
    self.essentials = essentials
    self.intents = intents
    self.skills = skills
    self.injectedContractIds = injectedContractIds
    self.skillAuthorization = skillAuthorization
    self.authorizationErrors = authorizationErrors
  }
}

/// Stable encoded snapshot returned by CLI and MCP contract resolution surfaces.
public struct ResolvedContractSnapshot: Codable, Equatable, Sendable {
  public let sessionId: String?
  public let personaId: String
  public let directiveId: String?
  public let kitIds: [String]
  public let injectedContractIds: [String]
  public let allowedSkillIds: [String]
  public let forbiddenSkillIds: [String]
  public let authorizedSkillIds: [String]
  public let requiredSkillIds: [String]
  public let unauthorizedRequiredSkillIds: [String]
  public let requestedSkillIds: [String]
  public let undeclaredRequestedSkillIds: [String]
  public let unauthorizedRequestedSkillIds: [String]
  public let isAuthorized: Bool
  public let failureReasons: [String]

  public init(
    sessionId: String?,
    personaId: String,
    directiveId: String?,
    kitIds: [String],
    injectedContractIds: [String],
    allowedSkillIds: [String],
    forbiddenSkillIds: [String],
    authorizedSkillIds: [String],
    requiredSkillIds: [String],
    unauthorizedRequiredSkillIds: [String],
    requestedSkillIds: [String],
    undeclaredRequestedSkillIds: [String],
    unauthorizedRequestedSkillIds: [String],
    isAuthorized: Bool,
    failureReasons: [String]
  ) {
    self.sessionId = sessionId
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitIds = kitIds
    self.injectedContractIds = injectedContractIds
    self.allowedSkillIds = allowedSkillIds
    self.forbiddenSkillIds = forbiddenSkillIds
    self.authorizedSkillIds = authorizedSkillIds
    self.requiredSkillIds = requiredSkillIds
    self.unauthorizedRequiredSkillIds = unauthorizedRequiredSkillIds
    self.requestedSkillIds = requestedSkillIds
    self.undeclaredRequestedSkillIds = undeclaredRequestedSkillIds
    self.unauthorizedRequestedSkillIds = unauthorizedRequestedSkillIds
    self.isAuthorized = isAuthorized
    self.failureReasons = failureReasons
  }
}

private struct RequiredSkillReference: Sendable {
  let sourceType: ResolverEntityType
  let sourceId: String
  let field: String
  let skillId: String
}

private struct ContractComponents {
  let persona: Persona
  let directive: Directive?
  let kits: [Kit]
  let essentials: [ResolvedEssential]
  let intents: [IntentTemplate]
  let skills: [Skill]
  let requiredSkillReferences: [RequiredSkillReference]
}

/// Resolves PersonaKit contract state without treating skill-authorization failures as hard errors.
public enum SessionContractResolver {
  public static func snapshot(from result: SessionContractResult) -> ResolvedContractSnapshot {
    ResolvedContractSnapshot(
      sessionId: result.sessionId,
      personaId: result.persona.id,
      directiveId: result.directive?.id,
      kitIds: result.kits.map(\.id).sorted(),
      injectedContractIds: result.injectedContractIds,
      allowedSkillIds: result.skillAuthorization.allowedSkillIds,
      forbiddenSkillIds: result.skillAuthorization.forbiddenSkillIds,
      authorizedSkillIds: result.skillAuthorization.authorizedSkillIds,
      requiredSkillIds: result.skillAuthorization.requiredSkillIds,
      unauthorizedRequiredSkillIds: result.skillAuthorization.unauthorizedRequiredSkillIds,
      requestedSkillIds: result.skillAuthorization.requestedSkillIds,
      undeclaredRequestedSkillIds: result.skillAuthorization.undeclaredRequestedSkillIds,
      unauthorizedRequestedSkillIds: result.skillAuthorization.unauthorizedRequestedSkillIds,
      isAuthorized: result.skillAuthorization.isAuthorized,
      failureReasons: result.skillAuthorization.failureReasons
    )
  }

  public static func resolve(
    scopes: ScopeSet,
    session: SessionFile,
    requestedSkillIds: [String] = [],
    fileManager: FileManager = .default
  ) throws -> SessionContractResult {
    let registry = try Registry.load(scopes: scopes, fileManager: fileManager)

    return try resolve(
      definition: SessionContractDefinition(
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: session.kitOverrides
      ),
      sessionId: session.id,
      registry: registry,
      scopes: scopes,
      requestedSkillIds: requestedSkillIds,
      fileManager: fileManager
    )
  }

  public static func resolve(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String?,
    kitOverrides: [String],
    requestedSkillIds: [String] = [],
    fileManager: FileManager = .default
  ) throws -> SessionContractResult {
    let registry = try Registry.load(scopes: scopes, fileManager: fileManager)

    return try resolve(
      definition: SessionContractDefinition(
        personaId: personaId,
        directiveId: directiveId,
        kitOverrides: kitOverrides.isEmpty ? nil : kitOverrides
      ),
      sessionId: nil,
      registry: registry,
      scopes: scopes,
      requestedSkillIds: requestedSkillIds,
      fileManager: fileManager
    )
  }

  static func resolve(
    definition: SessionContractDefinition,
    sessionId: String?,
    registry: Registry,
    scopes: ScopeSet,
    requestedSkillIds: [String] = [],
    fileManager: FileManager = .default
  ) throws -> SessionContractResult {
    let components = try resolveComponents(
      definition: definition,
      registry: registry,
      scopes: scopes,
      fileManager: fileManager
    )

    let authorization = evaluateSkillAuthorization(
      persona: components.persona,
      requiredSkillReferences: components.requiredSkillReferences,
      declaredSkillIds: Set(registry.skillsById.keys),
      requestedSkillIds: requestedSkillIds
    )

    let injectedContractIds = components.essentials
      .filter { $0.source == .systemBuiltIn }
      .map(\.id)

    return SessionContractResult(
      sessionId: sessionId,
      persona: components.persona,
      directive: components.directive,
      kits: components.kits.sorted { $0.id < $1.id },
      essentials: SystemEssentials.sortResolvedEssentialsForResolvedOutput(components.essentials),
      intents: components.intents.sorted { $0.id < $1.id },
      skills: components.skills.sorted { $0.id < $1.id },
      injectedContractIds: SystemEssentials.sortEssentialIdsForResolvedOutput(injectedContractIds),
      skillAuthorization: authorization.contract,
      authorizationErrors: authorization.errors
    )
  }

  private static func resolveComponents(
    definition: SessionContractDefinition,
    registry: Registry,
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> ContractComponents {
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

    var intentIds: [String] = []
    var requiredSkillReferences: [RequiredSkillReference] = []

    if let resolvedDirective = directive {
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
            RequiredSkillReference(
              sourceType: .kit,
              sourceId: kit.id,
              field: "skillIds",
              skillId: skillId
            )
          )
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
          RequiredSkillReference(
            sourceType: .directive,
            sourceId: resolvedDirective.id,
            field: "requiresSkillIds",
            skillId: skillId
          )
        )
      }
    }

    let uniqueIntentIds = uniqueSorted(intentIds)
    let resolvedIntents = uniqueIntentIds.compactMap { registry.intentTemplatesById[$0] }

    if directive != nil {
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

          requiredSkillReferences.append(
            RequiredSkillReference(
              sourceType: .intentTemplate,
              sourceId: intent.id,
              field: "requiresSkillIds",
              skillId: skillId
            )
          )
        }
      }
    }

    var essentialIds: [String] = []

    for kit in resolvedKits {
      for essentialId in kit.essentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"

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

    if directive != nil {
      for intent in resolvedIntents {
        for essentialId in intent.includesEssentialIds {
          let expectedPath = "Packs/essentials/\(essentialId).md"

          if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
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

    return ContractComponents(
      persona: resolvedPersona,
      directive: directive,
      kits: resolvedKits,
      essentials: resolvedEssentials,
      intents: resolvedIntents,
      skills: resolvedSkills,
      requiredSkillReferences: requiredSkillReferences
    )
  }

  private static func evaluateSkillAuthorization(
    persona: Persona,
    requiredSkillReferences: [RequiredSkillReference],
    declaredSkillIds: Set<String>,
    requestedSkillIds: [String]
  ) -> (contract: ResolvedSkillAuthorization, errors: [ResolverError]) {
    let allowedSkillIds = uniqueSorted(persona.allowedSkillIds)
    let forbiddenSkillIds = uniqueSorted(persona.forbiddenSkillIds)
    let conflictingPersonaSkillIds = allowedSkillIds.filter { forbiddenSkillIds.contains($0) }
    let authorizedSkillIds = allowedSkillIds.filter { !forbiddenSkillIds.contains($0) }
    let requiredSkillIds = uniqueSorted(requiredSkillReferences.map(\.skillId))

    let unauthorizedRequiredReferences = requiredSkillReferences.filter { reference in
      !authorizedSkillIds.contains(reference.skillId)
    }
    let unauthorizedRequiredSkillIds = uniqueSorted(unauthorizedRequiredReferences.map(\.skillId))
    let normalizedRequestedSkillIds = uniqueSorted(requestedSkillIds)
    let undeclaredRequestedSkillIds = normalizedRequestedSkillIds.filter {
      !declaredSkillIds.contains($0)
    }
    let unauthorizedRequestedSkillIds = normalizedRequestedSkillIds.filter { skillId in
      declaredSkillIds.contains(skillId) && !authorizedSkillIds.contains(skillId)
    }

    var failureReasons: [String] = conflictingPersonaSkillIds.map { skillId in
      "persona \(persona.id) lists \(skillId) in both allowedSkillIds and forbiddenSkillIds"
    }

    failureReasons.append(
      contentsOf: unauthorizedRequiredReferences.map { reference in
        "\(reference.sourceType.rawValue) \(reference.sourceId) requires unauthorized skill \(reference.skillId)"
      }
    )

    failureReasons.append(
      contentsOf: undeclaredRequestedSkillIds.map { skillId in
        "requested skill \(skillId) is not declared in PersonaKit"
      }
    )

    failureReasons.append(
      contentsOf: unauthorizedRequestedSkillIds.map { skillId in
        "requested skill \(skillId) is declared in PersonaKit but not authorized by persona \(persona.id)"
      }
    )

    let authorizationErrors =
      conflictingPersonaSkillIds.map { skillId in
        ResolverError.conflictingPersonaSkillId(
          sourceId: persona.id,
          field: "allowedSkillIds",
          missingId: skillId
        )
      }
      + unauthorizedRequiredReferences.map { reference in
        ResolverError.unauthorizedSkillId(
          sourceType: reference.sourceType,
          sourceId: reference.sourceId,
          field: reference.field,
          missingId: reference.skillId
        )
      }

    let contract = ResolvedSkillAuthorization(
      allowedSkillIds: allowedSkillIds,
      forbiddenSkillIds: forbiddenSkillIds,
      conflictingPersonaSkillIds: conflictingPersonaSkillIds,
      authorizedSkillIds: authorizedSkillIds,
      requiredSkillIds: requiredSkillIds,
      unauthorizedRequiredSkillIds: unauthorizedRequiredSkillIds,
      requestedSkillIds: normalizedRequestedSkillIds,
      undeclaredRequestedSkillIds: undeclaredRequestedSkillIds,
      unauthorizedRequestedSkillIds: unauthorizedRequestedSkillIds,
      isAuthorized:
        conflictingPersonaSkillIds.isEmpty
        && unauthorizedRequiredSkillIds.isEmpty
        && undeclaredRequestedSkillIds.isEmpty
        && unauthorizedRequestedSkillIds.isEmpty,
      failureReasons: failureReasons.sorted()
    )

    return (contract, authorizationErrors)
  }
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}
