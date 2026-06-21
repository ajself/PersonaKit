import Foundation

/// Builds the `@Sendable () -> URL?` global-scope provider shared by the workspace
/// builders and validator.
///
/// Preserves the historical resolution — an explicit URL wins (standardized once),
/// otherwise fall back to the dependency default — while deferring evaluation to call
/// time so a late-bound provider (see Studio's grant flow) reads the *current* granted
/// scope rather than a value frozen at `init`.
func makeGlobalScopeProvider(
  explicit: URL?,
  default defaultProvider: @escaping @Sendable () -> URL?
) -> @Sendable () -> URL? {
  if let explicit {
    let standardized = explicit.standardizedFileURL
    return { standardized }
  }

  return defaultProvider
}
