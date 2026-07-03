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
  public let skillIds: [String]?

  public init(
    id: String,
    version: String,
    name: String,
    summary: String,
    essentialIds: [String],
    referenceIds: [String]? = nil,
    skillIds: [String]?
  ) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
    self.essentialIds = essentialIds
    self.referenceIds = referenceIds
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

  /// Directive parameter contract exposed to downstream tools.
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

  /// Risk metadata attached to a directive.
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
  public let title: String
  public let goal: String
  public let steps: [Step]
  public let acceptanceCriteria: [String]
  public let verification: [VerificationItem]
  public let requiresSkillIds: [String]
  public let referenceIds: [String]?
  public let workstream: Workstream?
  public let parameters: [Parameter]
  public let risk: Risk?

  public init(
    id: String,
    version: String,
    title: String,
    goal: String,
    steps: [Step],
    acceptanceCriteria: [String],
    verification: [VerificationItem],
    requiresSkillIds: [String],
    referenceIds: [String]? = nil,
    workstream: Workstream? = nil,
    parameters: [Parameter] = [],
    risk: Risk? = nil
  ) {
    self.id = id
    self.version = version
    self.title = title
    self.goal = goal
    self.steps = steps
    self.acceptanceCriteria = acceptanceCriteria
    self.verification = verification
    self.requiresSkillIds = requiresSkillIds
    self.referenceIds = referenceIds
    self.workstream = workstream
    self.parameters = parameters
    self.risk = risk
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case version
    case title
    case goal
    case steps
    case acceptanceCriteria
    case verification
    case requiresSkillIds
    case referenceIds
    case workstream
    case parameters
    case risk
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.version = try container.decode(String.self, forKey: .version)
    self.title = try container.decode(String.self, forKey: .title)
    self.goal = try container.decode(String.self, forKey: .goal)
    self.steps = try container.decode([Step].self, forKey: .steps)
    self.acceptanceCriteria = try container.decode([String].self, forKey: .acceptanceCriteria)
    self.verification = try container.decode([VerificationItem].self, forKey: .verification)
    self.requiresSkillIds = try container.decode([String].self, forKey: .requiresSkillIds)
    self.referenceIds = try container.decodeIfPresent([String].self, forKey: .referenceIds)
    self.workstream = try container.decodeIfPresent(Workstream.self, forKey: .workstream)
    self.parameters = try container.decodeIfPresent([Parameter].self, forKey: .parameters) ?? []
    self.risk = try container.decodeIfPresent(Risk.self, forKey: .risk)
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
