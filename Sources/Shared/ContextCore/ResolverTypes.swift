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

public enum ResolvedEssentialSource: String, Equatable, Sendable {
  case file
  case systemBuiltIn
}

/// Metadata for an essential referenced by a resolved session.
public struct ResolvedEssential: Equatable, Sendable {
  public let id: String
  public let url: URL
  public let content: String?
  public let source: ResolvedEssentialSource

  public init(
    id: String,
    url: URL,
    content: String?,
    source: ResolvedEssentialSource
  ) {
    self.id = id
    self.url = url
    self.content = content
    self.source = source
  }
}

/// Source edge for a reference declared by a resolved session component.
public struct ResolvedReferenceSource: Codable, Equatable, Sendable {
  public let sourceType: ResolverEntityType
  public let sourceId: String
  public let field: String

  public init(
    sourceType: ResolverEntityType,
    sourceId: String,
    field: String
  ) {
    self.sourceType = sourceType
    self.sourceId = sourceId
    self.field = field
  }
}

/// Reference metadata made available to a resolved session without inlining its body.
public struct ResolvedReference: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let summary: String
  public let triggerRules: [ReferenceTriggerRule]
  public let sources: [ResolvedReferenceSource]

  public init(
    id: String,
    name: String,
    summary: String,
    triggerRules: [ReferenceTriggerRule],
    sources: [ResolvedReferenceSource]
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.triggerRules = triggerRules
    self.sources = sources
  }
}

/// Deterministic trigger inputs supplied by callers when evaluating references.
public struct ReferenceSelectionInput: Equatable, Sendable {
  public let targetPaths: [String]
  public let requestFlags: [String]

  public init(
    targetPaths: [String],
    requestFlags: [String]
  ) {
    self.targetPaths = Set(targetPaths.map(normalizeReferenceTargetPath)).sorted()
    self.requestFlags = Set(requestFlags.map(normalizeReferenceRequestFlag)).sorted()
  }

  public var isEmpty: Bool {
    targetPaths.isEmpty && requestFlags.isEmpty
  }
}

/// Deterministic reason explaining how a single trigger rule matched.
public struct ResolvedReferenceMatchRule: Codable, Equatable, Sendable {
  public let ruleIndex: Int
  public let matchedPathGlobs: [String]
  public let matchedPaths: [String]
  public let matchedRequestFlags: [String]

  public init(
    ruleIndex: Int,
    matchedPathGlobs: [String],
    matchedPaths: [String],
    matchedRequestFlags: [String]
  ) {
    self.ruleIndex = ruleIndex
    self.matchedPathGlobs = matchedPathGlobs
    self.matchedPaths = matchedPaths
    self.matchedRequestFlags = matchedRequestFlags
  }
}

/// Reference selected for expansion, with deterministic match reasons.
public struct ResolvedReferenceMatch: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let summary: String
  public let sources: [ResolvedReferenceSource]
  public let matchedRules: [ResolvedReferenceMatchRule]

  public init(
    id: String,
    name: String,
    summary: String,
    sources: [ResolvedReferenceSource],
    matchedRules: [ResolvedReferenceMatchRule]
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.sources = sources
    self.matchedRules = matchedRules
  }
}

/// Fully resolved PersonaKit entities for a single session.
public struct ResolvedSession: Sendable {
  public let persona: Persona
  public let directive: Directive
  public let kits: [Kit]
  public let essentials: [ResolvedEssential]
  public let availableReferences: [ResolvedReference]
  public let intents: [IntentTemplate]
  public let skills: [Skill]
  public let skillAuthorization: ResolvedSkillAuthorization

  public init(
    persona: Persona,
    directive: Directive,
    kits: [Kit],
    essentials: [ResolvedEssential],
    availableReferences: [ResolvedReference],
    intents: [IntentTemplate],
    skills: [Skill],
    skillAuthorization: ResolvedSkillAuthorization
  ) {
    self.persona = persona
    self.directive = directive
    self.kits = kits
    self.essentials = essentials
    self.availableReferences = availableReferences
    self.intents = intents
    self.skills = skills
    self.skillAuthorization = skillAuthorization
  }
}

/// Entity categories used to attribute resolution failures.
public enum ResolverEntityType: String, Codable, Equatable, Sendable {
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
  case missingReferenceId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case missingSkillId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
  case conflictingPersonaSkillId(sourceId: String, field: String, missingId: String)
  case unauthorizedSkillId(sourceType: ResolverEntityType, sourceId: String, field: String, missingId: String)
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
    case .missingReferenceId(let sourceType, _, _, _):
      return sourceType
    case .missingSkillId(let sourceType, _, _, _):
      return sourceType
    case .conflictingPersonaSkillId:
      return .persona
    case .unauthorizedSkillId(let sourceType, _, _, _):
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
    case .missingReferenceId(_, let sourceId, _, _):
      return sourceId
    case .missingSkillId(_, let sourceId, _, _):
      return sourceId
    case .conflictingPersonaSkillId(let sourceId, _, _):
      return sourceId
    case .unauthorizedSkillId(_, let sourceId, _, _):
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
    case .missingReferenceId(_, _, let field, _):
      return field
    case .missingSkillId(_, _, let field, _):
      return field
    case .conflictingPersonaSkillId(_, let field, _):
      return field
    case .unauthorizedSkillId(_, _, let field, _):
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
    case .missingReferenceId(_, _, _, let missingId):
      return missingId
    case .missingSkillId(_, _, _, let missingId):
      return missingId
    case .conflictingPersonaSkillId(_, _, let missingId):
      return missingId
    case .unauthorizedSkillId(_, _, _, let missingId):
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
    case .missingReferenceId:
      return "Missing reference id."
    case .missingSkillId:
      return "Missing skill id."
    case .conflictingPersonaSkillId:
      return "Skill id appears in both allowedSkillIds and forbiddenSkillIds."
    case .unauthorizedSkillId:
      return "Skill is not authorized by the resolved persona contract."
    case .missingEssentialFile(_, _, _, _, let expectedPath):
      return "Missing essential file at \(expectedPath)."
    }
  }
}

private func normalizeReferenceTargetPath(_ path: String) -> String {
  let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
  let normalized = trimmed.replacingOccurrences(of: "\\", with: "/")
  if normalized.hasPrefix("./") {
    return String(normalized.dropFirst(2))
  }
  return normalized
}

private func normalizeReferenceRequestFlag(_ flag: String) -> String {
  flag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
