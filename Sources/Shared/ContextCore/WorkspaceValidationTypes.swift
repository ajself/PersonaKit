import Foundation

/// Severity for a validation issue shown in Studio diagnostics.
public enum WorkspaceValidationSeverity: String, Codable, Sendable {
  case error
}

/// Entity categories used for diagnostics navigation in Studio.
public enum WorkspaceValidationEntityType: String, Codable, Sendable {
  case session
  case persona
  case kit
  case directive
  case intent
  case skill
  case essentials
}

/// Read-only validation issue rendered in Studio.
public struct WorkspaceValidationIssue: Equatable, Sendable {
  public let entityType: WorkspaceValidationEntityType
  public let entityId: String?
  public let field: String
  public let filePath: String?
  public let message: String
  public let severity: WorkspaceValidationSeverity

  public init(
    entityType: WorkspaceValidationEntityType,
    entityId: String?,
    field: String,
    filePath: String?,
    message: String,
    severity: WorkspaceValidationSeverity
  ) {
    self.entityType = entityType
    self.entityId = entityId
    self.field = field
    self.filePath = filePath
    self.message = message
    self.severity = severity
  }
}

/// Read-only diagnostics snapshot shown in Studio.
public struct WorkspaceValidationSnapshot: Equatable, Sendable {
  public let summary: String
  public let issues: [WorkspaceValidationIssue]

  public init(summary: String, issues: [WorkspaceValidationIssue]) {
    self.summary = summary
    self.issues = issues
  }

  public static let empty = WorkspaceValidationSnapshot(
    summary: "Validation has not run.",
    issues: []
  )
}

/// Dependency contract for workspace validation so app code can inject behavior.
public protocol WorkspaceValidating: Sendable {
  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot
}
