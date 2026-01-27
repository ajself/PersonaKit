import Foundation

/// Standard on-disk locations for PersonaKit packs and state.
public struct PersonaKitStoragePaths: Sendable, Hashable {
  public let root: URL
  public let packs: URL
  public let state: URL

  /// Creates storage paths rooted at the provided folder.
  public init(root: URL) {
    self.root = root
    self.packs = root.appendingPathComponent("Packs", isDirectory: true)
    self.state = root.appendingPathComponent("State", isDirectory: true)
  }

  /// Returns the default Application Support paths for the current user.
  public static func standard(homeDirectory: URL? = nil) -> PersonaKitStoragePaths {
    let resolvedHome = homeDirectory ?? FileClientProvider().fileClient.homeDirectory()
    let root =
      resolvedHome
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("PersonaKit", isDirectory: true)
    return PersonaKitStoragePaths(root: root)
  }
}

/// Helpers for naming pack directories in storage.
public enum PersonaKitStorage {
  /// Returns the preferred directory name for the given pack metadata.
  public static func preferredPackDirectoryName(for pack: PackMeta) -> String {
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    let preferred = name.isEmpty ? id : name
    return sanitizePackDirectoryName(preferred)
  }

  /// Sanitizes a pack name for safe directory use.
  public static func sanitizePackDirectoryName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "Untitled Pack"
    }
    var sanitized = trimmed
    sanitized = sanitized.replacingOccurrences(of: "/", with: "-")
    sanitized = sanitized.replacingOccurrences(of: "\\", with: "-")
    sanitized = sanitized.replacingOccurrences(of: ":", with: "-")
    return sanitized
  }

  /// Produces a unique directory name by appending a numeric suffix when needed.
  public static func uniquePackDirectoryName(preferred: String, existing: Set<String>) -> String {
    let base =
      preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "Untitled Pack" : preferred
    guard existing.contains(base) else { return base }
    var suffix = 2
    while true {
      let candidate = "\(base) \(suffix)"
      if !existing.contains(candidate) {
        return candidate
      }
      suffix += 1
    }
  }
}
