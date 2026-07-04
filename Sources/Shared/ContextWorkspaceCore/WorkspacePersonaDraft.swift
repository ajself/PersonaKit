import Foundation

/// Editable persona draft model used by shared persona-creation workflows.
public struct WorkspacePersonaDraft: Equatable, Sendable {
  public var id: String
  public var name: String
  public var summary: String
  public var responsibilities: [String]
  public var values: [String]
  public var nonGoals: [String]
  /// Ambient operating context (host, language, constraints). Optional to mirror
  /// the schema: `nil` means the field is absent, `[]` means an authored-empty
  /// list. The two must round-trip distinctly, so this is not collapsed to `[]`.
  public var environment: [String]?
  public var defaultKitIds: [String]
  public var allowedSkillIds: [String]
  public var forbiddenSkillIds: [String]
  public var forbiddenCapabilities: [String]

  public init(
    id: String,
    name: String,
    summary: String,
    responsibilities: [String],
    values: [String],
    nonGoals: [String],
    environment: [String]? = nil,
    defaultKitIds: [String],
    allowedSkillIds: [String],
    forbiddenSkillIds: [String],
    forbiddenCapabilities: [String] = []
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.responsibilities = responsibilities
    self.values = values
    self.nonGoals = nonGoals
    self.environment = environment
    self.defaultKitIds = defaultKitIds
    self.allowedSkillIds = allowedSkillIds
    self.forbiddenSkillIds = forbiddenSkillIds
    self.forbiddenCapabilities = forbiddenCapabilities
  }

  public static let empty = WorkspacePersonaDraft(
    id: "",
    name: "",
    summary: "",
    responsibilities: [],
    values: [],
    nonGoals: [],
    environment: nil,
    defaultKitIds: [],
    allowedSkillIds: [],
    forbiddenSkillIds: [],
    forbiddenCapabilities: []
  )
}

/// Validation results for a persona draft, including non-blocking warnings.
public struct WorkspacePersonaDraftValidation: Equatable, Sendable {
  public let errors: [String]
  public let warnings: [String]

  public init(
    errors: [String],
    warnings: [String]
  ) {
    self.errors = errors
    self.warnings = warnings
  }

  public var isValid: Bool {
    errors.isEmpty
  }
}
