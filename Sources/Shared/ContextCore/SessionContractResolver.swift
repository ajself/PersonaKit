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
    let components = try SessionContractComponentResolver.resolve(
      definition: definition,
      registry: registry,
      scopes: scopes,
      fileManager: fileManager
    )

    let authorization = SessionContractSkillAuthorizationEvaluator.evaluate(
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
}
