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
      skills: registry.skillsById.count
    )

    // Only warn about an empty root when nothing else already explains it. When errors
    // are present (missing Packs, schema/decode failures) the emptiness is not silent.
    let warnings =
      errors.isEmpty
      ? emptyRootWarnings(scopes: scopes, counts: counts, fileManager: fileManager)
      : []

    if bootstrap.hasSchemaErrors {
      // Skip reference checks when schema errors exist to avoid noisy cascades.
      return ValidationResult(counts: counts, errors: errors, warnings: warnings)
    }

    errors.append(
      contentsOf: try ValidatorReferenceChecker.validate(
        registry: registry,
        scopes: scopes,
        fileManager: fileManager
      )
    )

    return ValidationResult(counts: counts, errors: errors, warnings: warnings)
  }

  /// Warns when a resolved scope root exists on disk but contributed no entities.
  ///
  /// A root that resolves yet loads nothing otherwise reports `errors=0`, which reads
  /// as a healthy validation. This is most often an enumeration gap — files are present
  /// but the directory scan returned them empty, as observed for hidden `.personakit`
  /// roots on iCloud-synced volumes — so the empty result is surfaced rather than passing
  /// silently. Purely advisory: it never adds to the error count or changes exit status.
  static func emptyRootWarnings(
    scopes: ScopeSet,
    counts: ValidationCounts,
    fileManager: FileManager
  ) -> [String] {
    let totalLoaded =
      counts.personas + counts.kits + counts.directives + counts.skills

    guard totalLoaded == 0 else { return [] }

    return scopes.loadOrder.compactMap { root in
      var isDirectory: ObjCBool = false
      guard
        fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        return nil
      }

      return
        "Root resolved at \(root.path) but loaded 0 entities. If files exist there, the "
        + "scan may have skipped them (e.g. hidden or iCloud-synced locations); verify "
        + "with `ls \(root.path)/Packs`."
    }
  }
}
