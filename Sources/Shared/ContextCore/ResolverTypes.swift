import Foundation

/// User-provided identifiers and optional kit overrides for session resolution.
public struct SessionDefinition {
  public let personaId: String
  public let directiveId: String
  public let kitOverrides: [String]?

  public init(
    personaId: String,
    directiveId: String,
    kitOverrides: [String]?
  ) {
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitOverrides = kitOverrides
  }
}

/// Metadata for an essential referenced by a resolved session.
public struct ResolvedEssential: Equatable, Sendable {
  public let id: String
  public let url: URL
  public let content: String?

  public init(
    id: String,
    url: URL,
    content: String?
  ) {
    self.id = id
    self.url = url
    self.content = content
  }
}

/// Fully resolved PersonaKit entities for a single session.
public struct ResolvedSession: Sendable {
  public let persona: Persona
  public let directive: Directive
  public let kits: [Kit]
  public let essentials: [ResolvedEssential]
  public let intents: [IntentTemplate]
  public let skills: [Skill]

  public init(
    persona: Persona,
    directive: Directive,
    kits: [Kit],
    essentials: [ResolvedEssential],
    intents: [IntentTemplate],
    skills: [Skill]
  ) {
    self.persona = persona
    self.directive = directive
    self.kits = kits
    self.essentials = essentials
    self.intents = intents
    self.skills = skills
  }
}

/// Entity categories used to attribute resolution failures.
public enum ResolverEntityType: String, Sendable {
  case sessionDefinition = "session"
  case persona
  case kit
  case directive
  case intentTemplate
  case skill

  /// Stable sort priority used for deterministic error ordering.
  public var sortOrder: Int {
    switch self {
    case .sessionDefinition:
      return 0
    case .persona:
      return 1
    case .kit:
      return 2
    case .directive:
      return 3
    case .intentTemplate:
      return 4
    case .skill:
      return 5
    }
  }
}

/// Structured resolution failure for missing ids or files.
public enum ResolverError: Error, Equatable {
  case missingPersona(field: String, id: String)
  case missingDirective(field: String, id: String)
  case missingKitId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingIntentId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingSkillId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingEssentialFile(
    sourceType: ResolverEntityType,
    sourceId: String,
    field: String,
    missingId: String,
    expectedPath: String
  )

  /// The entity type that referenced the missing dependency.
  public var sourceType: ResolverEntityType {
    switch self {
    case .missingPersona:
      return .sessionDefinition
    case .missingDirective:
      return .sessionDefinition
    case .missingKitId(let sourceType, _, _, _):
      return sourceType
    case .missingIntentId(let sourceType, _, _, _):
      return sourceType
    case .missingSkillId(let sourceType, _, _, _):
      return sourceType
    case .missingEssentialFile(let sourceType, _, _, _, _):
      return sourceType
    }
  }

  /// The id of the entity that referenced the missing dependency.
  public var sourceId: String {
    switch self {
    case .missingPersona:
      return "session"
    case .missingDirective:
      return "session"
    case .missingKitId(_, let sourceId, _, _):
      return sourceId
    case .missingIntentId(_, let sourceId, _, _):
      return sourceId
    case .missingSkillId(_, let sourceId, _, _):
      return sourceId
    case .missingEssentialFile(_, let sourceId, _, _, _):
      return sourceId
    }
  }

  /// The schema field that contained the missing reference.
  public var field: String {
    switch self {
    case .missingPersona(let field, _):
      return field
    case .missingDirective(let field, _):
      return field
    case .missingKitId(_, _, let field, _):
      return field
    case .missingIntentId(_, _, let field, _):
      return field
    case .missingSkillId(_, _, let field, _):
      return field
    case .missingEssentialFile(_, _, let field, _, _):
      return field
    }
  }

  /// The id or value that could not be resolved.
  public var missingId: String {
    switch self {
    case .missingPersona(_, let id):
      return id
    case .missingDirective(_, let id):
      return id
    case .missingKitId(_, _, _, let missingId):
      return missingId
    case .missingIntentId(_, _, _, let missingId):
      return missingId
    case .missingSkillId(_, _, _, let missingId):
      return missingId
    case .missingEssentialFile(_, _, _, let missingId, _):
      return missingId
    }
  }

  /// Human-readable error message used in CLI and MCP output.
  public var message: String {
    switch self {
    case .missingPersona:
      return "Missing persona id."
    case .missingDirective:
      return "Missing directive id."
    case .missingKitId:
      return "Missing kit id."
    case .missingIntentId:
      return "Missing intent template id."
    case .missingSkillId:
      return "Missing skill id."
    case .missingEssentialFile(_, _, _, _, let expectedPath):
      return "Missing essential file at \(expectedPath)."
    }
  }
}

/// Aggregate resolution failure with deterministic sorting.
public struct ResolverResolutionError: Error, Equatable {
  public let errors: [ResolverError]

  /// Creates a resolution error and sorts nested errors for stable output.
  public init(errors: [ResolverError]) {
    self.errors = ResolverResolutionError.sort(errors: errors)
  }

  private static func sort(errors: [ResolverError]) -> [ResolverError] {
    return errors.sorted { lhs, rhs in
      if lhs.sourceType.sortOrder != rhs.sourceType.sortOrder {
        return lhs.sourceType.sortOrder < rhs.sourceType.sortOrder
      }

      if lhs.sourceId != rhs.sourceId {
        return lhs.sourceId < rhs.sourceId
      }

      if lhs.field != rhs.field {
        return lhs.field < rhs.field
      }

      if lhs.missingId != rhs.missingId {
        return lhs.missingId < rhs.missingId
      }

      return lhs.message < rhs.message
    }
  }
}
