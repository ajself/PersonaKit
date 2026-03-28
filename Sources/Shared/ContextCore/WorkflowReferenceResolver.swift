import Foundation

/// Errors produced while evaluating triggered references for a resolved session.
public enum ReferenceLookupError: Error {
  case validationFailed(ValidationResult)
  case resolutionFailed(ResolverResolutionError)
  case referenceResolutionFailed(ReferenceResolutionError)
}

/// Deterministic result for a reference lookup against a resolved workflow session.
public struct ReferenceLookupResult: Codable, Equatable, Sendable {
  public let availableReferences: [ResolvedReference]
  public let matchedReferences: [ResolvedReferenceMatch]

  public init(
    availableReferences: [ResolvedReference],
    matchedReferences: [ResolvedReferenceMatch]
  ) {
    self.availableReferences = availableReferences
    self.matchedReferences = matchedReferences
  }
}

/// Evaluates declared workflow references from explicit, caller-supplied trigger inputs.
public enum WorkflowReferenceResolver {
  public static func resolve(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    input: ReferenceSelectionInput,
    fileManager: FileManager = .default
  ) throws -> ReferenceLookupResult {
    let validation = try Validator.validate(scopes: scopes, fileManager: fileManager)

    if !validation.errors.isEmpty {
      throw ReferenceLookupError.validationFailed(validation)
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
      throw ReferenceLookupError.resolutionFailed(error)
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
    input: ReferenceSelectionInput,
    fileManager: FileManager = .default
  ) throws -> ReferenceLookupResult {
    let matchedReferences = ReferenceSupport.resolveMatches(
      availableReferences: session.availableReferences,
      input: input
    )

    if !matchedReferences.isEmpty {
      do {
        _ = try ReferenceSupport.loadExpandedDocuments(
          matches: matchedReferences,
          scopes: scopes,
          fileManager: fileManager
        )
      } catch let error as ReferenceResolutionError {
        throw ReferenceLookupError.referenceResolutionFailed(error)
      }
    }

    return ReferenceLookupResult(
      availableReferences: session.availableReferences.sorted { $0.id < $1.id },
      matchedReferences: matchedReferences.sorted { $0.id < $1.id }
    )
  }
}
