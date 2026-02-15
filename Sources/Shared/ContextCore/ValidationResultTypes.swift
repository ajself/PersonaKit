import Foundation

/// Entity categories used for deterministic validation reporting.
public enum ValidationEntityType: String, Sendable {
  case persona
  case kit
  case directive
  case intent
  case skill
  case essentials

  /// Stable sort priority used when ordering validation errors.
  public var sortOrder: Int {
    switch self {
    case .persona:
      return 1
    case .kit:
      return 2
    case .directive:
      return 3
    case .intent:
      return 4
    case .skill:
      return 5
    case .essentials:
      return 6
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

  public init(
    entityType: ValidationEntityType,
    entityId: String?,
    field: String,
    missingId: String?,
    expectedPath: String?,
    message: String
  ) {
    self.entityType = entityType
    self.entityId = entityId
    self.field = field
    self.missingId = missingId
    self.expectedPath = expectedPath
    self.message = message
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
  public let intents: Int
  public let skills: Int
  public let essentials: Int

  public init(
    personas: Int,
    kits: Int,
    directives: Int,
    intents: Int,
    skills: Int,
    essentials: Int
  ) {
    self.personas = personas
    self.kits = kits
    self.directives = directives
    self.intents = intents
    self.skills = skills
    self.essentials = essentials
  }

  public static let zero = ValidationCounts(
    personas: 0,
    kits: 0,
    directives: 0,
    intents: 0,
    skills: 0,
    essentials: 0
  )
}

/// Deterministic validation result including entity counts and sorted errors.
public struct ValidationResult: Equatable, Sendable {
  public let counts: ValidationCounts
  public let errors: [ValidationError]

  /// Human-readable summary string used in user-facing output.
  public var summary: String {
    return
      "Validation summary: personas=\(counts.personas) kits=\(counts.kits) directives=\(counts.directives) intents=\(counts.intents) skills=\(counts.skills) essentials=\(counts.essentials) errors=\(errors.count)"
  }

  /// Creates a validation result and sorts errors for stable output.
  public init(counts: ValidationCounts, errors: [ValidationError]) {
    self.counts = counts
    self.errors = ValidationResult.sort(errors: errors)
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
