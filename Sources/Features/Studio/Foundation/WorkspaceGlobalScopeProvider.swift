import Foundation
import Synchronization

/// Late-bindable, thread-safe source for the global library scope shared by a
/// `WorkspaceStore`'s builders and validator.
///
/// The workspace builders are immutable `Sendable` structs that read the global scope
/// through an injected `@Sendable () -> URL?` provider. This box is the single backing
/// that provider reads, letting `WorkspaceStore.setGlobalScope(_:)` apply a user grant
/// after launch without rebuilding the store (which holds the open workspace + UI
/// state). When no scope has been granted, the box falls back to the supplied default
/// so behavior matches a store that never had a grant.
public final class WorkspaceGlobalScopeProvider: Sendable {
  private let grantedURL: Mutex<URL?>
  private let fallback: @Sendable () -> URL?

  /// - Parameters:
  ///   - initialURL: The initially granted global root, if any (e.g. from the launch
  ///     environment override or a resolved bookmark). Standardized on store.
  ///   - fallback: Resolves the effective scope when nothing is granted — typically the
  ///     live `~/.personakit` default, which is `nil` under the app sandbox.
  public init(
    initialURL: URL?,
    fallback: @escaping @Sendable () -> URL?
  ) {
    self.grantedURL = Mutex(initialURL?.standardizedFileURL)
    self.fallback = fallback
  }

  /// The effective global scope: the granted URL if present, else the fallback.
  public func current() -> URL? {
    if let granted = grantedURL.withLock({ $0 }) {
      return granted
    }

    return fallback()
  }

  /// Updates the granted global root (or clears it with `nil`). The change is observed
  /// by every builder reading this provider on its next call.
  public func setURL(_ url: URL?) {
    grantedURL.withLock { $0 = url?.standardizedFileURL }
  }
}
