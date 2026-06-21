import Foundation

/// Creates and resolves the app-wide security-scoped bookmark for the granted global
/// PersonaKit library. Mirrors `StudioRecentWorkspaceBookmarkClient`'s option sets, but
/// surfaces `isStale` so a stale bookmark can be re-persisted.
protocol StudioGlobalLibraryBookmarking {
  func bookmarkData(for url: URL) -> Data?
  func resolve(_ bookmarkData: Data) -> StudioGlobalLibraryBookmarkResolution?
  func startAccessing(_ url: URL) -> Bool
  func stopAccessing(_ url: URL)
}

/// A resolved bookmark plus whether the OS flagged it stale (the caller should re-persist).
struct StudioGlobalLibraryBookmarkResolution: Equatable {
  let url: URL
  let isStale: Bool
}

struct StudioGlobalLibraryBookmarkClient: StudioGlobalLibraryBookmarking {
  func bookmarkData(for url: URL) -> Data? {
    try? url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  func resolve(_ bookmarkData: Data) -> StudioGlobalLibraryBookmarkResolution? {
    var isStale = false

    guard
      let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    else {
      return nil
    }

    return StudioGlobalLibraryBookmarkResolution(
      url: url.standardizedFileURL,
      isStale: isStale
    )
  }

  func startAccessing(_ url: URL) -> Bool {
    url.startAccessingSecurityScopedResource()
  }

  func stopAccessing(_ url: URL) {
    url.stopAccessingSecurityScopedResource()
  }
}

/// Remembers a single app-wide grant of the global PersonaKit library across launches so
/// the user grants once, not every session.
///
/// On launch, ``resolveGrantedURL()`` returns the granted root — beginning security-scoped
/// access and re-persisting a stale bookmark — to seed the global-scope provider. After a
/// user grant, ``persist(grantedURL:)`` stores the bookmark and begins access. Exactly one
/// bookmark is kept: the single granted global root (whatever folder the user picked).
@MainActor
public final class StudioGlobalLibraryAccess {
  private static let storageKey = "studio.globalLibraryBookmark"

  private let bookmarkClient: any StudioGlobalLibraryBookmarking
  private let userDefaults: UserDefaults
  private var accessedURL: URL?

  init(
    bookmarkClient: any StudioGlobalLibraryBookmarking = StudioGlobalLibraryBookmarkClient(),
    userDefaults: UserDefaults = StudioLaunchConfiguration.userDefaults()
  ) {
    self.bookmarkClient = bookmarkClient
    self.userDefaults = userDefaults
  }

  /// Resolves the persisted grant, beginning access and re-persisting a stale bookmark.
  /// Returns `nil` when nothing is granted or the bookmark cannot be resolved.
  @discardableResult
  func resolveGrantedURL() -> URL? {
    guard let data = userDefaults.data(forKey: Self.storageKey) else {
      return nil
    }

    guard let resolution = bookmarkClient.resolve(data) else {
      return nil
    }

    if resolution.isStale,
      let refreshed = bookmarkClient.bookmarkData(for: resolution.url)
    {
      userDefaults.set(refreshed, forKey: Self.storageKey)
    }

    beginAccess(to: resolution.url)
    return resolution.url
  }

  /// Persists the user-granted root and begins access for the current session.
  /// Returns `false` when a bookmark could not be created (nothing is stored).
  @discardableResult
  func persist(grantedURL: URL) -> Bool {
    guard let data = bookmarkClient.bookmarkData(for: grantedURL) else {
      return false
    }

    userDefaults.set(data, forKey: Self.storageKey)
    beginAccess(to: grantedURL)
    return true
  }

  /// Releases any in-progress security-scoped access.
  func endAccess() {
    if let accessedURL {
      bookmarkClient.stopAccessing(accessedURL)
    }

    accessedURL = nil
  }

  private func beginAccess(to url: URL) {
    endAccess()

    if bookmarkClient.startAccessing(url) {
      accessedURL = url
    }
  }
}
