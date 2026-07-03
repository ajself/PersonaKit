import Foundation

/// Dependency contract for snapshot loading so app code and tests can inject behavior.
public protocol WorkspaceSnapshotBuilding: Sendable {
  func build(workspaceURL: URL) throws -> WorkspaceSnapshot
}

/// Source location for an item loaded into a workspace snapshot.
public enum WorkspaceSourceScope: String, Codable, Sendable {
  case project
  case global

  /// Human-readable label shown in Studio.
  public var displayName: String {
    switch self {
    case .project:
      return "Project"
    case .global:
      return "Global"
    }
  }
}

/// Skill-specific metadata surfaced in Studio list previews.
public struct WorkspaceSkillMetadata: Equatable, Sendable {
  public let description: String
  public let providedBy: [String]
  public let riskLevel: String
  public let requiresHumanReview: Bool
  public let notes: [String]

  public init(
    description: String,
    providedBy: [String],
    riskLevel: String,
    requiresHumanReview: Bool,
    notes: [String]
  ) {
    self.description = description
    self.providedBy = providedBy
    self.riskLevel = riskLevel
    self.requiresHumanReview = requiresHumanReview
    self.notes = notes
  }
}

/// Read-only list item for personas, directives, kits, skills, and essentials.
public struct WorkspaceListItem: Equatable, Sendable {
  public let id: String
  public let displayName: String
  public let fileURL: URL
  public let sourceScope: WorkspaceSourceScope
  public let workstreamId: String?
  public let workstreamPhase: String?
  public let skillMetadata: WorkspaceSkillMetadata?

  public init(
    id: String,
    displayName: String,
    fileURL: URL,
    sourceScope: WorkspaceSourceScope,
    workstreamId: String? = nil,
    workstreamPhase: String? = nil,
    skillMetadata: WorkspaceSkillMetadata? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.fileURL = fileURL
    self.sourceScope = sourceScope
    self.workstreamId = workstreamId
    self.workstreamPhase = workstreamPhase
    self.skillMetadata = skillMetadata
  }
}

/// Read-only list item for sessions.
public struct WorkspaceSessionListItem: Equatable, Sendable {
  public let id: String
  public let personaId: String
  public let directiveId: String
  public let fileURL: URL
  public let sourceScope: WorkspaceSourceScope

  public init(
    id: String,
    personaId: String,
    directiveId: String,
    fileURL: URL,
    sourceScope: WorkspaceSourceScope
  ) {
    self.id = id
    self.personaId = personaId
    self.directiveId = directiveId
    self.fileURL = fileURL
    self.sourceScope = sourceScope
  }
}

/// Aggregated read-only Studio data loaded from project/global scopes.
public struct WorkspaceSnapshot: Equatable, Sendable {
  public let sessions: [WorkspaceSessionListItem]
  public let personas: [WorkspaceListItem]
  public let directives: [WorkspaceListItem]
  public let kits: [WorkspaceListItem]
  public let skills: [WorkspaceListItem]
  public let essentials: [WorkspaceListItem]

  public init(
    sessions: [WorkspaceSessionListItem],
    personas: [WorkspaceListItem],
    directives: [WorkspaceListItem],
    kits: [WorkspaceListItem],
    skills: [WorkspaceListItem],
    essentials: [WorkspaceListItem]
  ) {
    self.sessions = sessions
    self.personas = personas
    self.directives = directives
    self.kits = kits
    self.skills = skills
    self.essentials = essentials
  }

  public static let empty = WorkspaceSnapshot(
    sessions: [],
    personas: [],
    directives: [],
    kits: [],
    skills: [],
    essentials: []
  )
}

/// User-facing workspace snapshot loading failure.
public struct WorkspaceSnapshotBuildError: LocalizedError, Sendable {
  public let message: String

  public init(message: String) {
    self.message = message
  }

  public var errorDescription: String? {
    message
  }
}
