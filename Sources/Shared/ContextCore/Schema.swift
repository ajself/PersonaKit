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
  public let forbiddenCapabilities: [String]?

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
    forbiddenSkillIds: [String],
    forbiddenCapabilities: [String]? = nil
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
    self.forbiddenCapabilities = forbiddenCapabilities
  }
}

/// Kit definition loaded from `Packs/kits/*.kit.json`.
public struct Kit: Codable, Sendable {
  public let id: String
  public let version: String
  public let name: String
  public let summary: String
  public let essentialIds: [String]
  public let referenceIds: [String]?
  public let intentTemplateIds: [String]?
  public let skillIds: [String]?

  public init(
    id: String,
    version: String,
    name: String,
    summary: String,
    essentialIds: [String],
    referenceIds: [String]? = nil,
    intentTemplateIds: [String]?,
    skillIds: [String]?
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
    self.essentialIds = essentialIds
    self.referenceIds = referenceIds
    self.intentTemplateIds = intentTemplateIds
    self.skillIds = skillIds
  }
}

/// Directive definition loaded from `Packs/directives/*.directive.json`.
public struct Directive: Codable, Sendable {
  /// Session-routing metadata for a directive phase within a larger workstream.
  public struct Workstream: Codable, Sendable {
    /// Session node participating in the workstream graph.
    public struct Node: Codable, Equatable, Sendable {
      public let sessionId: String
      public let phase: String

      public init(
        sessionId: String,
        phase: String
      ) {
        self.sessionId = sessionId
        self.phase = phase
      }
    }

    /// Directed edge between two session nodes in the workstream graph.
    public struct Edge: Codable, Equatable, Sendable {
      public let fromSessionId: String
      public let toSessionId: String
      public let kind: String

      public init(
        fromSessionId: String,
        toSessionId: String,
        kind: String
      ) {
        self.fromSessionId = fromSessionId
        self.toSessionId = toSessionId
        self.kind = kind
      }
    }

    public let id: String
    public let phase: String
    public let entrySessionId: String
    public let requiredCloseoutSessionId: String?
    public let nodes: [Node]
    public let edges: [Edge]

    public init(
      id: String,
      phase: String,
      entrySessionId: String,
      requiredCloseoutSessionId: String?,
      nodes: [Node],
      edges: [Edge]
    ) {
      self.id = id
      self.phase = phase
      self.entrySessionId = entrySessionId
      self.requiredCloseoutSessionId = requiredCloseoutSessionId
      self.nodes = nodes
      self.edges = edges
    }

    public func node(forSessionId sessionId: String?) -> Node? {
      guard let sessionId else {
        return nil
      }

      return nodes.first { $0.sessionId == sessionId }
    }

    public func nextSessionIds(
      fromSessionId sessionId: String?
    ) -> [String] {
      guard let node = node(forSessionId: sessionId) else {
        return []
      }

      return
        edges
        .filter { $0.fromSessionId == node.sessionId }
        .map(\.toSessionId)
    }

    public var orderedNodes: [Node] {
      nodes
    }

    public var orderedEdges: [Edge] {
      edges
    }
  }

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
  public let referenceIds: [String]?
  public let workstream: Workstream?

  public init(
    id: String,
    version: String,
    title: String,
    goal: String,
    steps: [Step],
    acceptanceCriteria: [String],
    verification: [VerificationItem],
    requiresIntentTemplateIds: [String],
    requiresSkillIds: [String],
    referenceIds: [String]? = nil,
    workstream: Workstream? = nil
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
    self.referenceIds = referenceIds
    self.workstream = workstream
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
  public let referenceIds: [String]?
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
    referenceIds: [String]? = nil,
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
    self.referenceIds = referenceIds
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
  public let capabilities: [String]?
  public let risk: Risk
  public let notes: [String]

  public init(
    id: String,
    version: String,
    name: String,
    description: String,
    providedBy: [String],
    capabilities: [String]? = nil,
    risk: Risk,
    notes: [String]
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.description = description
    self.providedBy = providedBy
    self.capabilities = capabilities
    self.risk = risk
    self.notes = notes
  }
}

/// Deterministic trigger rule for on-demand reference expansion.
public struct ReferenceTriggerRule: Codable, Equatable, Sendable {
  public let pathGlobs: [String]?
  public let referenceTags: [String]?

  public init(
    pathGlobs: [String]? = nil,
    referenceTags: [String]? = nil
  ) {
    self.pathGlobs = pathGlobs
    self.referenceTags = referenceTags
  }
}

/// Reference definition loaded from `Packs/references/*.reference.json`.
public struct Reference: Codable, Equatable, Sendable {
  public let id: String
  public let version: String
  public let name: String
  public let summary: String
  public let triggerRules: [ReferenceTriggerRule]

  public init(
    id: String,
    version: String,
    name: String,
    summary: String,
    triggerRules: [ReferenceTriggerRule]
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
    self.triggerRules = triggerRules
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
