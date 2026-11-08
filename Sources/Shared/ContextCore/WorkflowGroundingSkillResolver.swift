import Foundation

/// Errors produced while evaluating triggered grounding skills for a resolved session.
public enum GroundingSkillLookupError: Error {
  case validationFailed(ValidationResult)
  /// `validation` is the scoped validation that passed, so a caller can still report warnings.
  case resolutionFailed(ResolverResolutionError, validation: ValidationResult)
  /// `validation` is the scoped validation that passed, so a caller can still report warnings.
  case groundingSkillResolutionFailed(GroundingSkillResolutionError, validation: ValidationResult)
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

/// A grounding-skill lookup and the scoped validation it passed. Kept apart from the lookup result, whose JSON
/// is the command output.
public struct GroundingSkillLookup: Equatable, Sendable {
  public let result: GroundingSkillLookupResult
  /// Library errors outside the session, as warnings.
  public let validation: ValidationResult

  public init(result: GroundingSkillLookupResult, validation: ValidationResult) {
    self.result = result
    self.validation = validation
  }
}

/// Evaluates declared workflow grounding skills from explicit, caller-supplied trigger inputs.
public enum WorkflowGroundingSkillResolver {
  public static func resolve(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    sessionId: String? = nil,
    input: SkillTriggerSelectionInput,
    fileManager: FileManager = .default
  ) throws -> GroundingSkillLookupResult {
    try resolveWithValidation(
      scopes: scopes,
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      sessionId: sessionId,
      input: input,
      fileManager: fileManager
    )
    .result
  }

  /// Resolves grounding skills after a validation scoped to this session: errors elsewhere in the library come
  /// back as warnings instead of blocking.
  public static func resolveWithValidation(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    sessionId: String? = nil,
    input: SkillTriggerSelectionInput,
    fileManager: FileManager = .default
  ) throws -> GroundingSkillLookup {
    let validation = try Validator.validate(
      scopes: scopes,
      session: ValidationSessionScope(
        sessionId: sessionId,
        personaId: personaId,
        directiveId: directiveId,
        kitOverrides: kitOverrides
      ),
      fileManager: fileManager
    )

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
      throw GroundingSkillLookupError.resolutionFailed(error, validation: validation)
    }

    let result = try resolve(
      session: session,
      scopes: scopes,
      input: input,
      validation: validation,
      fileManager: fileManager
    )

    return GroundingSkillLookup(result: result, validation: validation)
  }

  private static func resolve(
    session: ResolvedSession,
    scopes: ScopeSet,
    input: SkillTriggerSelectionInput,
    validation: ValidationResult,
    fileManager: FileManager
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
        throw GroundingSkillLookupError.groundingSkillResolutionFailed(error, validation: validation)
      }
    }

    return GroundingSkillLookupResult(
      availableGroundingSkills: session.availableGroundingSkills.sorted { $0.id < $1.id },
      matchedGroundingSkills: matchedGroundingSkills.sorted { $0.id < $1.id }
    )
  }
}
