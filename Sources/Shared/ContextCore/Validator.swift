import Foundation

/// Performs schema and cross-reference validation for PersonaKit pack data.
public struct Validator {
  /// Validates a single root as project scope only.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory containing `Packs/`.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic validation result.
  public static func validate(root: URL, fileManager: FileManager = .default) throws -> ValidationResult {
    try validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      fileManager: fileManager
    )
  }

  /// Validates schema and references across project/global scopes.
  ///
  /// - Parameters:
  ///   - scopes: Scope set used for loading, schema checks, and path resolution.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic validation result.
  public static func validate(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> ValidationResult {
    let bootstrap = try ValidatorBootstrap.prepare(
      scopes: scopes,
      fileManager: fileManager
    )
    var errors = bootstrap.errors

    guard let registry = bootstrap.registry else {
      return ValidationResult(counts: .zero, errors: errors)
    }

    let counts = ValidationCounts(
      personas: registry.personasById.count,
      kits: registry.kitsById.count,
      directives: registry.directivesById.count,
      references: registry.referencesById.count,
      skills: registry.skillsById.count,
      essentials: bootstrap.essentialIds.count
    )

    if bootstrap.hasSchemaErrors {
      // Skip reference checks when schema errors exist to avoid noisy cascades.
      return ValidationResult(counts: counts, errors: errors)
    }

    errors.append(
      contentsOf: try ValidatorReferenceChecker.validate(
        registry: registry,
        scopes: scopes,
        fileManager: fileManager
      )
    )

    return ValidationResult(counts: counts, errors: errors)
  }
}
