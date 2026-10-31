import Foundation

@MainActor
package protocol StudioRecentWorkspacesPersisting: AnyObject {
  var storageValue: String { get set }
}

/// Persists the recent-workspaces list in `UserDefaults` under a stable key, so existing
/// users keep their recents across releases.
@MainActor
package final class StudioRecentWorkspacesUserDefaultsStorage: StudioRecentWorkspacesPersisting {
  package nonisolated static let storageKey = "studio.recentWorkspaces"

  private let userDefaults: UserDefaults

  package init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  package var storageValue: String {
    get {
      userDefaults.string(forKey: Self.storageKey) ?? "[]"
    }

    set {
      userDefaults.set(newValue, forKey: Self.storageKey)
    }
  }
}

/// Reads and writes the security-scoped bookmark for the granted global library.
@MainActor
package protocol StudioGlobalLibraryBookmarkStoring: AnyObject {
  func bookmarkData() -> Data?
  func setBookmarkData(_ data: Data)
}

/// Persists the global-library bookmark in `UserDefaults` under a stable key, so existing
/// users keep their grant across releases.
@MainActor
package final class StudioGlobalLibraryBookmarkUserDefaultsStore: StudioGlobalLibraryBookmarkStoring {
  package nonisolated static let storageKey = "studio.globalLibraryBookmark"

  private let userDefaults: UserDefaults

  package init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  package func bookmarkData() -> Data? {
    userDefaults.data(forKey: Self.storageKey)
  }

  package func setBookmarkData(_ data: Data) {
    userDefaults.set(data, forKey: Self.storageKey)
  }
}
