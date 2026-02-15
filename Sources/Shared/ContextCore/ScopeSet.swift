import Foundation

/// Resolved project/global PersonaKit scope roots and their deterministic lookup orders.
public struct ScopeSet: Equatable, Sendable {
  /// Project-local PersonaKit root, if one is available.
  public let projectScopeURL: URL?

  /// Global PersonaKit root, if one is available.
  public let globalScopeURL: URL?

  /// Creates a scope set with normalized file URLs.
  ///
  /// - Parameters:
  ///   - projectScopeURL: Optional project-local scope root.
  ///   - globalScopeURL: Optional global scope root.
  public init(projectScopeURL: URL?, globalScopeURL: URL?) {
    self.projectScopeURL = projectScopeURL?.standardizedFileURL
    self.globalScopeURL = globalScopeURL?.standardizedFileURL
  }

  /// Indicates whether both project and global scopes are absent.
  public var isEmpty: Bool {
    projectScopeURL == nil && globalScopeURL == nil
  }

  /// Returns roots in registry/schema load order (global first, then project).
  public var loadOrder: [URL] {
    uniqueRoots([globalScopeURL, projectScopeURL].compactMap { $0 })
  }

  /// Returns roots in resolution order for path lookups (project first, then global).
  public var resolutionOrder: [URL] {
    uniqueRoots([projectScopeURL, globalScopeURL].compactMap { $0 })
  }

  /// Removes duplicate roots while preserving first-seen order.
  ///
  /// Dedupe compares canonicalized filesystem paths so symlink aliases collapse to
  /// a single root when both entries reference the same physical directory.
  private func uniqueRoots(_ roots: [URL]) -> [URL] {
    var seen: Set<String> = []

    return roots.filter { url in
      let key = canonicalRootKey(for: url)

      return seen.insert(key).inserted
    }
  }

  private func canonicalRootKey(for url: URL) -> String {
    return url.resolvingSymlinksInPath().standardizedFileURL.path
  }
}
