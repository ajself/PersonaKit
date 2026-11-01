import ContextWorkspaceCore
import Darwin
import Foundation

/// Thread-safe source for the global library scope shared by a `WorkspaceStore`'s
/// builders and validator.
///
/// The workspace builders are immutable `Sendable` structs that read the global scope
/// through an injected `@Sendable () -> URL?` provider. This box is the single backing
/// that provider reads. When no explicit scope is set, the box re-evaluates the supplied
/// fallback on every read, so a `~/.personakit` created after launch is picked up.
public final class WorkspaceGlobalScopeProvider: Sendable {
  private let explicitURL: URL?
  private let fallback: @Sendable () -> URL?

  /// - Parameters:
  ///   - initialURL: An explicit global root, if any (e.g. from the launch environment
  ///     override). Standardized on store.
  ///   - fallback: Resolves the effective scope when no explicit root is set — typically
  ///     ``userHomeGlobalScopeURL(fileManager:)``.
  public init(
    initialURL: URL?,
    fallback: @escaping @Sendable () -> URL?
  ) {
    self.explicitURL = initialURL?.standardizedFileURL
    self.fallback = fallback
  }

  /// The effective global scope: the explicit URL if present, else the fallback.
  public func current() -> URL? {
    explicitURL ?? fallback()
  }

  /// Resolves `~/.personakit` in the user's real home directory when it exists.
  ///
  /// Under the app sandbox `homeDirectoryForCurrentUser` is the app container, so the
  /// home directory comes from the password database instead. The sandbox grants access
  /// to this one folder through a home-relative-path entitlement.
  public static func userHomeGlobalScopeURL(fileManager: FileManager = .default) -> URL? {
    let candidate = (userHomeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser)
      .appendingPathComponent(".personakit", isDirectory: true)

    guard WorkspaceScopeResolver.directoryExists(candidate, fileManager: fileManager) else {
      return nil
    }

    return candidate.standardizedFileURL
  }

  // Resolved once: `getpwuid` returns shared static storage, and `current()` runs on
  // concurrent builder reads.
  private static let userHomeDirectoryURL: URL? = {
    guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else {
      return nil
    }

    return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
  }()
}
