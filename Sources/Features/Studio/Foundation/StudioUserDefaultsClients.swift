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
