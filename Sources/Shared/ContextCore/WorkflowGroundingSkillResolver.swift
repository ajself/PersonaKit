import Foundation

/// Errors produced while evaluating triggered grounding skills for a resolved session.
public enum GroundingSkillLookupError: Error {
  case validationFailed(ValidationResult)
  case resolutionFailed(ResolverResolutionError)
  case groundingSkillResolutionFailed(GroundingSkillResolutionError)
}

/// Deterministic result for a grounding-skill lookup against a resolved workflow session.
public struct GroundingSkillLookupResult: Codable, Equatable, Sendable {
  public let availableGroundingSkills: [ResolvedGroundingSkill]
  public let matchedGroundingSkills: [ResolvedGroundingSkillMatch]

  public init(
    availableGroundingSkills: [ResolvedGroundingSkill],
    matchedGroundingSkills: [ResolvedGroundingSkillMatch]
  ) {
    self.availableGroundingSkills = availableGroundingSkills
    self.matchedGroundingSkills = matchedGroundingSkills
  }
}

/// Evaluates declared workflow grounding skills from explicit, caller-supplied trigger inputs.
public enum WorkflowGroundingSkillResolver {
  public static func resolve(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    input: SkillTriggerSelectionInput,
    fileManager: FileManager = .default
  ) throws -> GroundingSkillLookupResult {
    let validation = try Validator.validate(scopes: scopes, fileManager: fileManager)

    if !validation.errors.isEmpty {
      throw GroundingSkillLookupError.validationFailed(validation)
    }

    let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
    let definition = SessionDefinition(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides.isEmpty ? nil : kitOverrides
    )
    let session: ResolvedSession

    do {
      session = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes,
        fileManager: fileManager
      )
    } catch let error as ResolverResolutionError {
      throw GroundingSkillLookupError.resolutionFailed(error)
    }

    return try resolve(
      session: session,
      scopes: scopes,
      input: input,
      fileManager: fileManager
    )
  }

  public static func resolve(
    session: ResolvedSession,
    scopes: ScopeSet,
    input: SkillTriggerSelectionInput,
    fileManager: FileManager = .default
  ) throws -> GroundingSkillLookupResult {
    let matchedGroundingSkills = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: session.availableGroundingSkills,
      input: input
    )

    if !matchedGroundingSkills.isEmpty {
      do {
        _ = try GroundingSkillSupport.loadExpandedDocuments(
          matches: matchedGroundingSkills,
          scopes: scopes,
          fileManager: fileManager
        )
      } catch let error as GroundingSkillResolutionError {
        throw GroundingSkillLookupError.groundingSkillResolutionFailed(error)
      }
    }

    return GroundingSkillLookupResult(
      availableGroundingSkills: session.availableGroundingSkills.sorted { $0.id < $1.id },
      matchedGroundingSkills: matchedGroundingSkills.sorted { $0.id < $1.id }
    )
  }
}
