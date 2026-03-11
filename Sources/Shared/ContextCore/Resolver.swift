import Foundation

/// Resolves a session definition into concrete PersonaKit entities.
public struct Resolver {
  /// Resolves a session using explicit scope inputs.
  ///
  /// - Parameters:
  ///   - definition: Persona/directive ids and optional kit overrides.
  ///   - registry: In-memory entity registry loaded from disk.
  ///   - scopes: Scope set used to resolve essential file locations.
  ///   - fileManager: File system interface used for file existence checks.
  /// - Returns: Fully resolved session entities.
  /// - Throws: ``ResolverResolutionError`` when references cannot be resolved.
  public static func resolve(
    definition: SessionDefinition,
    registry: Registry,
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> ResolvedSession {
    let contract = try SessionContractResolver.resolve(
      definition: SessionContractDefinition(
        personaId: definition.personaId,
        directiveId: definition.directiveId,
        kitOverrides: definition.kitOverrides
      ),
      sessionId: nil,
      registry: registry,
      scopes: scopes,
      fileManager: fileManager
    )

    if !contract.authorizationErrors.isEmpty {
      throw ResolverResolutionError(errors: contract.authorizationErrors)
    }

    guard let resolvedDirective = contract.directive else {
      throw ResolverResolutionError(
        errors: [
          .missingDirective(field: "directiveId", id: definition.directiveId)
        ]
      )
    }

    return ResolvedSession(
      persona: contract.persona,
      directive: resolvedDirective,
      kits: contract.kits,
      essentials: contract.essentials,
      intents: contract.intents,
      skills: contract.skills,
      skillAuthorization: contract.skillAuthorization
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
  public static func resolve(
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
