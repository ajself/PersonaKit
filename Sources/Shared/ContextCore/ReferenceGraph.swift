import Foundation

/// Entity categories that participate in PersonaKit reference tracing.
public enum ReferenceEntityType: String, Sendable, CaseIterable, Comparable {
  case persona
  case kit
  case directive
  case intent
  case reference
  case skill
  case essential
  case session

  public static func < (lhs: ReferenceEntityType, rhs: ReferenceEntityType) -> Bool {
    lhs.order < rhs.order
  }

  private var order: Int {
    switch self {
    case .session: return 0
    case .persona: return 1
    case .kit: return 2
    case .directive: return 3
    case .intent: return 4
    case .reference: return 5
    case .skill: return 6
    case .essential: return 7
    }
  }

  /// Whether this entity can be invoked directly from the CLI without being
  /// referenced by another entity (`--session`, `--persona`, `--directive`).
  ///
  /// Such entities are legitimate entry points, so an unreferenced one is not
  /// necessarily dead. Sessions are excluded from orphan reporting entirely;
  /// personas and directives are reported but flagged as still-invocable.
  public var isDirectlyInvocable: Bool {
    switch self {
    case .session, .persona, .directive:
      return true
    case .kit, .intent, .reference, .skill, .essential:
      return false
    }
  }
}

/// A single typed entity in the reference graph.
public struct ReferenceNode: Hashable, Sendable, Comparable {
  public let type: ReferenceEntityType
  public let id: String

  public init(type: ReferenceEntityType, id: String) {
    self.type = type
    self.id = id
  }

  public static func < (lhs: ReferenceNode, rhs: ReferenceNode) -> Bool {
    lhs.type == rhs.type ? lhs.id < rhs.id : lhs.type < rhs.type
  }
}

/// A directed reference from one entity to another via a named field.
public struct ReferenceEdge: Hashable, Sendable {
  public let from: ReferenceNode
  public let to: ReferenceNode
  public let field: String

  public init(from: ReferenceNode, to: ReferenceNode, field: String) {
    self.from = from
    self.to = to
    self.field = field
  }
}

/// Deterministic forward/reverse reference graph over a resolved PersonaKit scope set.
///
/// The graph is intentionally read-only: it reports how entities reference one another
/// so callers can trace "what uses this" and "what does this use", and surface entities
/// that nothing references (orphans). Sessions are entry points and never orphans.
public struct ReferenceGraph: Sendable {
  /// Every known entity node in the loaded scopes.
  public let nodes: Set<ReferenceNode>

  /// Every directed reference edge between known nodes.
  public let edges: [ReferenceEdge]

  /// Builds a graph from a loaded registry, the discovered essential ids, and sessions.
  public init(registry: Registry, essentialIds: [String], sessions: [SessionFile]) {
    var nodes: Set<ReferenceNode> = []
    var edges: [ReferenceEdge] = []

    func node(_ type: ReferenceEntityType, _ id: String) -> ReferenceNode {
      ReferenceNode(type: type, id: id)
    }

    for persona in registry.personas { nodes.insert(node(.persona, persona.id)) }
    for kit in registry.kits { nodes.insert(node(.kit, kit.id)) }
    for directive in registry.directives { nodes.insert(node(.directive, directive.id)) }
    for intent in registry.intentTemplates { nodes.insert(node(.intent, intent.id)) }
    for reference in registry.references { nodes.insert(node(.reference, reference.id)) }
    for skill in registry.skills { nodes.insert(node(.skill, skill.id)) }
    for essentialId in essentialIds { nodes.insert(node(.essential, essentialId)) }
    for session in sessions { nodes.insert(node(.session, session.id)) }

    func link(_ from: ReferenceNode, _ toType: ReferenceEntityType, _ ids: [String], _ field: String) {
      for id in ids {
        edges.append(ReferenceEdge(from: from, to: node(toType, id), field: field))
      }
    }

    for persona in registry.personas {
      let from = node(.persona, persona.id)
      link(from, .kit, persona.defaultKitIds, "defaultKitIds")
      link(from, .skill, persona.allowedSkillIds, "allowedSkillIds")
      link(from, .skill, persona.forbiddenSkillIds, "forbiddenSkillIds")
    }

    for kit in registry.kits {
      let from = node(.kit, kit.id)
      link(from, .essential, kit.essentialIds, "essentialIds")
      link(from, .reference, kit.referenceIds ?? [], "referenceIds")
      link(from, .intent, kit.intentTemplateIds ?? [], "intentTemplateIds")
      link(from, .skill, kit.skillIds ?? [], "skillIds")
    }

    for directive in registry.directives {
      let from = node(.directive, directive.id)
      link(from, .intent, directive.requiresIntentTemplateIds, "requiresIntentTemplateIds")
      link(from, .skill, directive.requiresSkillIds, "requiresSkillIds")
      link(from, .reference, directive.referenceIds ?? [], "referenceIds")
    }

    for intent in registry.intentTemplates {
      let from = node(.intent, intent.id)
      link(from, .essential, intent.includesEssentialIds, "includesEssentialIds")
      link(from, .skill, intent.requiresSkillIds, "requiresSkillIds")
      link(from, .reference, intent.referenceIds ?? [], "referenceIds")
    }

    for session in sessions {
      let from = node(.session, session.id)
      link(from, .persona, [session.personaId], "personaId")
      link(from, .directive, [session.directiveId], "directiveId")
      link(from, .kit, session.kitOverrides ?? [], "kitOverrides")
    }

    self.nodes = nodes
    self.edges = edges
  }

  /// Returns the nodes matching an id across all entity types, sorted deterministically.
  public func nodes(withId id: String) -> [ReferenceNode] {
    nodes.filter { $0.id == id }.sorted()
  }

  /// Outgoing edges from a node (what this entity references), sorted deterministically.
  public func outgoing(from node: ReferenceNode) -> [ReferenceEdge] {
    edges.filter { $0.from == node }.sorted { ($0.to, $0.field) < ($1.to, $1.field) }
  }

  /// Incoming edges to a node (what references this entity), sorted deterministically.
  public func incoming(to node: ReferenceNode) -> [ReferenceEdge] {
    edges.filter { $0.to == node }.sorted { ($0.from, $0.field) < ($1.from, $1.field) }
  }

  /// Known non-session nodes that nothing references. Sessions are entry points and excluded.
  public func orphans() -> [ReferenceNode] {
    let referenced = Set(edges.map(\.to))

    return nodes
      .filter { $0.type != .session && !referenced.contains($0) }
      .sorted()
  }
}
