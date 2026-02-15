import Foundation

/// Resolves project/global PersonaKit scope roots from local environment paths.
public struct ScopeRootResolver: Sendable {
  private let projectLocator: ProjectPersonaKitLocator
  private let globalLocator: GlobalPersonaKitLocator

  /// Creates a resolver with optional path overrides for deterministic tests.
  ///
  /// - Parameters:
  ///   - startingURL: Optional project walk-up starting point.
  ///   - homeDirectory: Optional home directory for global scope lookup.
  public init(
    startingURL: URL? = nil,
    homeDirectory: URL? = nil
  ) {
    self.projectLocator = ProjectPersonaKitLocator(startingURL: startingURL)
    self.globalLocator = GlobalPersonaKitLocator(homeDirectory: homeDirectory)
  }

  /// Returns discovered scope roots, or `nil` when neither scope exists.
  ///
  /// - Returns: A `ScopeSet` containing discovered project/global URLs.
  public func locate() -> ScopeSet? {
    let project = projectLocator.locate()
    let global = globalLocator.locate()

    if project == nil && global == nil {
      return nil
    }

    return ScopeSet(projectScopeURL: project, globalScopeURL: global)
  }
}
