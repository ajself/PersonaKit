import ContextCore
import Foundation

/// Public validation bridge between Studio and PersonaKit validator internals.
public struct WorkspaceValidator: WorkspaceValidating, Sendable {
  private let dependencies: WorkspaceValidatorDependencies
  private let globalScopeURL: URL?

  /// Creates a workspace validator with live filesystem behavior.
  public init(globalScopeURL: URL? = nil) {
    let dependencies = WorkspaceValidatorDependencies.live()
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  /// Creates a workspace validator with injected dependencies (for tests).
  public init(
    globalScopeURL: URL? = nil,
    dependencies: WorkspaceValidatorDependencies
  ) {
    self.dependencies = dependencies

    if let globalScopeURL {
      self.globalScopeURL = globalScopeURL.standardizedFileURL
    } else {
      self.globalScopeURL = dependencies.defaultGlobalScopeURL()
    }
  }

  /// Validates project/global scopes for a selected workspace.
  ///
  /// - Parameter workspaceURL: Project workspace root selected by the user.
  /// - Returns: Validation snapshot containing deterministic issues.
  /// - Throws: ``WorkspaceSnapshotBuildError`` when `.personakit/Packs` is missing.
  public func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    let projectScopeURL = try scopeResolver().resolveProjectScopeURL(workspaceURL)
    let scopes = ScopeSet(projectScopeURL: projectScopeURL, globalScopeURL: globalScopeURL)
    let result = try dependencies.validateScopes(scopes)

    return WorkspaceValidationSnapshot(
      summary: result.summary,
      issues: result.errors.map { issue(from: $0, scopes: scopes) }
    )
  }

  private func issue(
    from error: ValidationError,
    scopes: ScopeSet
  ) -> WorkspaceValidationIssue {
    WorkspaceValidationIssue(
      entityType: map(error.entityType),
      entityId: error.entityId,
      field: error.field,
      filePath: resolveFilePath(error.expectedPath, scopes: scopes),
      message: error.message,
      severity: .error
    )
  }

  private func map(_ entityType: ValidationEntityType) -> WorkspaceValidationEntityType {
    switch entityType {
    case .persona:
      return .persona
    case .kit:
      return .kit
    case .directive:
      return .directive
    case .intent:
      return .intent
    case .skill:
      return .skill
    case .essentials:
      return .essentials
    }
  }

  private func resolveFilePath(_ expectedPath: String?, scopes: ScopeSet) -> String? {
    guard let expectedPath else {
      return nil
    }

    if expectedPath.hasPrefix("/") {
      return expectedPath
    }

    var matches: [String] = []

    for root in scopes.resolutionOrder {
      let candidate = root.appendingPathComponent(expectedPath)

      if dependencies.fileExists(candidate) {
        matches.append(candidate.path())
      }
    }

    if matches.count == 1 {
      return matches[0]
    }

    return expectedPath
  }

  private func scopeResolver() -> WorkspaceScopeResolver {
    WorkspaceScopeResolver(
      directoryExists: dependencies.directoryExists
    )
  }
}

/// Injectable filesystem and validation behavior for `WorkspaceValidator`.
public struct WorkspaceValidatorDependencies: Sendable {
  let directoryExists: @Sendable (URL) -> Bool
  let fileExists: @Sendable (URL) -> Bool
  let defaultGlobalScopeURL: @Sendable () -> URL?
  let validateScopes: @Sendable (ScopeSet) throws -> ValidationResult

  /// Creates dependency closures for deterministic validator behavior in tests or previews.
  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    fileExists: @escaping @Sendable (URL) -> Bool,
    defaultGlobalScopeURL: @escaping @Sendable () -> URL?,
    validateScopes: @escaping @Sendable (ScopeSet) throws -> ValidationResult
  ) {
    self.directoryExists = directoryExists
    self.fileExists = fileExists
    self.defaultGlobalScopeURL = defaultGlobalScopeURL
    self.validateScopes = validateScopes
  }

  /// Live dependency set backed by `FileManager` and `Validator`.
  static func live() -> WorkspaceValidatorDependencies {
    WorkspaceValidatorDependencies(
      directoryExists: { url in
        WorkspaceScopeResolver.directoryExists(
          url,
          fileManager: .default
        )
      },
      fileExists: { url in
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.path)
      },
      defaultGlobalScopeURL: {
        WorkspaceScopeResolver.defaultGlobalScopeURL(fileManager: .default)
      },
      validateScopes: { scopes in
        try Validator.validate(scopes: scopes, fileManager: .default)
      }
    )
  }
}
