import Foundation

/// Entity categories used for deterministic validation reporting.
public enum ValidationEntityType: String, Sendable {
  /// A structural problem with the `Packs` root itself (missing directory, not a
  /// directory) rather than a decodable entity. Kept distinct from `kit` so a
  /// pack-root failure and a real kit error never share a diagnostics label.
  case packsRoot = "packs"
  case session
  case persona
  case kit
  case directive
  case skill

  /// Stable sort priority used when ordering validation errors.
  public var sortOrder: Int {
    switch self {
    case .packsRoot:
      return 0
    case .session:
      return 1
    case .persona:
      return 2
    case .kit:
      return 3
    case .directive:
      return 4
    case .skill:
      return 5
    }
  }
}

/// Structured validation issue for a single entity reference or schema violation.
public struct ValidationError: Error, Equatable, Sendable {
  public let entityType: ValidationEntityType
  public let entityId: String?
  public let field: String
  public let missingId: String?
  public let expectedPath: String?
  public let message: String
  /// `true` when this error is an unresolved reference to a shared entity or file
  /// (e.g. a missing persona/kit/skill/reference id) that a scope not loaded in this
  /// run — such as the global library — could still satisfy.
  /// `false` for structural problems (schema, decode, id mismatch, unsafe paths,
  /// intra-entity conflicts) that no additional scope can fix.
  public let referencesUnresolvedID: Bool

  public init(
    entityType: ValidationEntityType,
    entityId: String?,
    field: String,
    missingId: String?,
    expectedPath: String?,
    message: String,
    referencesUnresolvedID: Bool = false
  ) {
    self.entityType = entityType
    self.entityId = entityId
    self.field = field
    self.missingId = missingId
    self.expectedPath = expectedPath
    self.message = message
    self.referencesUnresolvedID = referencesUnresolvedID
  }

  /// Renders a stable single-line description for CLI and MCP output.
  public func lineDescription() -> String {
    var parts: [String] = [entityType.rawValue]

    if let entityId {
      parts.append(entityId)
    }

    parts.append(field + ":")
    parts.append(message)

    if let missingId {
      parts.append("missingId=\(missingId)")
    }

    if let expectedPath {
      parts.append("expectedPath=\(expectedPath)")
    }

    return parts.joined(separator: " ")
  }
}

/// Count summary for loaded entities encountered during validation.
public struct ValidationCounts: Equatable, Sendable {
  public let personas: Int
  public let kits: Int
  public let directives: Int
  public let skills: Int

  public init(
    personas: Int,
    kits: Int,
    directives: Int,
    skills: Int
  ) {
    self.personas = personas
    self.kits = kits
    self.directives = directives
    self.skills = skills
  }

  public static let zero = ValidationCounts(
    personas: 0,
    kits: 0,
    directives: 0,
    skills: 0
  )
}

/// Deterministic validation result including entity counts and sorted errors.
public struct ValidationResult: Equatable, Sendable {
  public let counts: ValidationCounts
  public let errors: [ValidationError]

  /// Non-fatal advisories that should not pass silently, e.g. a root that resolved
  /// on disk but loaded zero entities. Warnings never affect the error count or exit
  /// status; they exist so an empty scope cannot masquerade as a clean validation.
  public let warnings: [String]

  /// Errors in library entities a scoped validation did not need, reported as warnings. Always empty for a
  /// library-wide validation; they never block and never count toward `errors`.
  public let outOfScopeErrors: [ValidationError]

  /// Human-readable summary string used in user-facing output.
  public var summary: String {
    return
      "Validation summary: personas=\(counts.personas) kits=\(counts.kits) directives=\(counts.directives) skills=\(counts.skills) warnings=\(warnings.count + outOfScopeErrors.count) errors=\(errors.count)"
  }

  /// Every warning as one line each: advisories first, then out-of-scope errors in sorted order.
  public var warningLines: [String] {
    warnings + outOfScopeErrors.map { $0.lineDescription() }
  }

  /// What a handoff reports on stderr: the summary, each error, then each warning as `warning: <line>`.
  public var reportLines: [String] {
    [summary] + errors.map { $0.lineDescription() } + warningLines.map { "warning: " + $0 }
  }

  /// Creates a validation result and sorts errors for stable output.
  public init(
    counts: ValidationCounts,
    errors: [ValidationError],
    warnings: [String] = [],
    outOfScopeErrors: [ValidationError] = []
  ) {
    self.counts = counts
    self.errors = ValidationResult.sort(errors: errors)
    self.warnings = warnings
    self.outOfScopeErrors = ValidationResult.sort(errors: outOfScopeErrors)
  }

  private static func sort(errors: [ValidationError]) -> [ValidationError] {
    return errors.sorted { lhs, rhs in
      if lhs.entityType.sortOrder != rhs.entityType.sortOrder {
        return lhs.entityType.sortOrder < rhs.entityType.sortOrder
      }

      let lhsId = lhs.entityId ?? ""
      let rhsId = rhs.entityId ?? ""

      if lhsId != rhsId {
        return lhsId < rhsId
      }

      if lhs.field != rhs.field {
        return lhs.field < rhs.field
      }

      let lhsMissing = lhs.missingId ?? ""
      let rhsMissing = rhs.missingId ?? ""

      if lhsMissing != rhsMissing {
        return lhsMissing < rhsMissing
      }

      let lhsPath = lhs.expectedPath ?? ""
      let rhsPath = rhs.expectedPath ?? ""

      if lhsPath != rhsPath {
        return lhsPath < rhsPath
      }

      return lhs.message < rhs.message
    }
  }
}
