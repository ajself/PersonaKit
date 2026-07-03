import ContextCore
import Foundation

/// Entity categories rendered in the Studio session dependency map.
public enum WorkspaceSessionMapNodeKind: String, Codable, Sendable {
  case session
  case persona
  case directive
  case kit
  case skill
  case essential

  var sortOrder: Int {
    switch self {
    case .session:
      return 0
    case .persona:
      return 1
    case .directive:
      return 2
    case .kit:
      return 3
    case .skill:
      return 4
    case .essential:
      return 5
    }
  }
}

/// Renderable node in the Studio session dependency map.
public struct WorkspaceSessionMapNode: Equatable, Sendable {
  public let key: String
  public let id: String
  public let displayName: String
  public let kind: WorkspaceSessionMapNodeKind
  public let isMissing: Bool
  public let badges: [String]

  public init(
    key: String,
    id: String,
    displayName: String,
    kind: WorkspaceSessionMapNodeKind,
    isMissing: Bool,
    badges: [String]
  ) {
    self.key = key
    self.id = id
    self.displayName = displayName
    self.kind = kind
    self.isMissing = isMissing
    self.badges = badges
  }
}

/// Directed edge in the Studio session dependency map.
public struct WorkspaceSessionMapEdge: Equatable, Sendable {
  public let fromKey: String
  public let toKey: String
  public let reason: String

  public init(
    fromKey: String,
    toKey: String,
    reason: String
  ) {
    self.fromKey = fromKey
    self.toKey = toKey
    self.reason = reason
  }
}

/// Session dependency map payload rendered by Studio.
public struct WorkspaceSessionMap: Equatable, Sendable {
  public let nodes: [WorkspaceSessionMapNode]
  public let edges: [WorkspaceSessionMapEdge]
  public let resolutionErrors: [ResolverError]
  public let isFullyResolved: Bool

  public init(
    nodes: [WorkspaceSessionMapNode],
    edges: [WorkspaceSessionMapEdge],
    resolutionErrors: [ResolverError],
    isFullyResolved: Bool
  ) {
    self.nodes = nodes
    self.edges = edges
    self.resolutionErrors = resolutionErrors
    self.isFullyResolved = isFullyResolved
  }
}

/// Contract for building session dependency maps from workspace-backed data.
public protocol WorkspaceSessionMapBuilding: Sendable {
  func build(
    workspaceURL: URL,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> WorkspaceSessionMap
}
