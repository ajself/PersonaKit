import Foundation

/// Persona definition loaded from `Packs/personas/*.persona.json`.
public struct Persona: Codable, Sendable {
  public let id: String
  public let version: String
  public let name: String
  public let summary: String
  public let responsibilities: [String]
  public let values: [String]
  public let nonGoals: [String]
  public let defaultKitIds: [String]
  public let allowedSkillIds: [String]
  public let forbiddenSkillIds: [String]

  public init(
    id: String,
    version: String,
    name: String,
    summary: String,
    responsibilities: [String],
    values: [String],
    nonGoals: [String],
    defaultKitIds: [String],
    allowedSkillIds: [String],
    forbiddenSkillIds: [String]
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
    self.responsibilities = responsibilities
    self.values = values
    self.nonGoals = nonGoals
    self.defaultKitIds = defaultKitIds
    self.allowedSkillIds = allowedSkillIds
    self.forbiddenSkillIds = forbiddenSkillIds
  }
}

/// Kit definition loaded from `Packs/kits/*.kit.json`.
public struct Kit: Codable, Sendable {
  public let id: String
  public let version: String
  public let name: String
  public let summary: String
  public let essentialIds: [String]
  public let intentTemplateIds: [String]?
  public let skillIds: [String]?

  public init(
    id: String,
    version: String,
    name: String,
    summary: String,
    essentialIds: [String],
    intentTemplateIds: [String]?,
    skillIds: [String]?
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
    self.essentialIds = essentialIds
    self.intentTemplateIds = intentTemplateIds
    self.skillIds = skillIds
  }
}

/// Directive definition loaded from `Packs/directives/*.directive.json`.
public struct Directive: Codable, Sendable {
  /// Ordered directive step with optional human review gate.
  public struct Step: Codable, Sendable {
    public let text: String
    public let requiresReview: Bool?

    public init(
      text: String,
      requiresReview: Bool?
    ) {
      self.text = text
      self.requiresReview = requiresReview
    }
  }

  /// Verification checklist entry for a directive.
  public struct VerificationItem: Codable, Sendable {
    public let kind: String
    public let text: String

    public init(
      kind: String,
      text: String
    ) {
      self.kind = kind
      self.text = text
    }
  }

  public let id: String
  public let version: String
  public let title: String
  public let goal: String
  public let steps: [Step]
  public let acceptanceCriteria: [String]
  public let verification: [VerificationItem]
  public let requiresIntentTemplateIds: [String]
  public let requiresSkillIds: [String]

  public init(
    id: String,
    version: String,
    title: String,
    goal: String,
    steps: [Step],
    acceptanceCriteria: [String],
    verification: [VerificationItem],
    requiresIntentTemplateIds: [String],
    requiresSkillIds: [String]
  ) {
    self.id = id
    self.version = version
    self.title = title
    self.goal = goal
    self.steps = steps
    self.acceptanceCriteria = acceptanceCriteria
    self.verification = verification
    self.requiresIntentTemplateIds = requiresIntentTemplateIds
    self.requiresSkillIds = requiresSkillIds
  }
}

/// Intent template loaded from `Packs/intents/*.intent.json`.
public struct IntentTemplate: Codable, Sendable {
  /// Intent parameter contract exposed to downstream tools.
  public struct Parameter: Codable, Sendable {
    public let name: String
    public let type: String
    public let required: Bool

    public init(
      name: String,
      type: String,
      required: Bool
    ) {
      self.name = name
      self.type = type
      self.required = required
    }
  }

  /// Machine-readable relationship rules applied across multiple parameters.
  public struct ParameterConstraint: Codable, Sendable {
    public let kind: String
    public let parameterNames: [String]

    public init(
      kind: String,
      parameterNames: [String]
    ) {
      self.kind = kind
      self.parameterNames = parameterNames
    }
  }

  /// Risk metadata attached to an intent template.
  public struct Risk: Codable, Sendable {
    public let level: String
    public let requiresHumanReview: Bool
    public let notes: [String]

    public init(
      level: String,
      requiresHumanReview: Bool,
      notes: [String]
    ) {
      self.level = level
      self.requiresHumanReview = requiresHumanReview
      self.notes = notes
    }
  }

  public let id: String
  public let version: String
  public let name: String
  public let description: String
  public let parameters: [Parameter]
  public let parameterConstraints: [ParameterConstraint]?
  public let includesEssentialIds: [String]
  public let requiresSkillIds: [String]
  public let risk: Risk

  public init(
    id: String,
    version: String,
    name: String,
    description: String,
    parameters: [Parameter],
    parameterConstraints: [ParameterConstraint]? = nil,
    includesEssentialIds: [String],
    requiresSkillIds: [String],
    risk: Risk
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.description = description
    self.parameters = parameters
    self.parameterConstraints = parameterConstraints
    self.includesEssentialIds = includesEssentialIds
    self.requiresSkillIds = requiresSkillIds
    self.risk = risk
  }
}

/// Skill definition loaded from `Packs/skills/*.skill.json`.
public struct Skill: Codable, Sendable {
  /// Risk metadata attached to a skill.
  public struct Risk: Codable, Sendable {
    public let level: String
    public let requiresHumanReview: Bool
    public let notes: [String]

    public init(
      level: String,
      requiresHumanReview: Bool,
      notes: [String]
    ) {
      self.level = level
      self.requiresHumanReview = requiresHumanReview
      self.notes = notes
    }
  }

  public let id: String
  public let version: String
  public let name: String
  public let description: String
  public let providedBy: [String]
  public let risk: Risk
  public let notes: [String]

  public init(
    id: String,
    version: String,
    name: String,
    description: String,
    providedBy: [String],
    risk: Risk,
    notes: [String]
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.description = description
    self.providedBy = providedBy
    self.risk = risk
    self.notes = notes
  }
}

/// In-memory essential markdown document content.
public struct EssentialDocument: Sendable {
  public let id: String
  public let content: String

  public init(
    id: String,
    content: String
  ) {
    self.id = id
    self.content = content
  }
}
