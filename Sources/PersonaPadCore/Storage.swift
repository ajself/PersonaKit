import Foundation

public struct PersonaPadStoragePaths: Sendable, Hashable {
  public let root: URL
  public let packs: URL
  public let state: URL

  public init(root: URL) {
    self.root = root
    self.packs = root.appendingPathComponent("Packs", isDirectory: true)
    self.state = root.appendingPathComponent("State", isDirectory: true)
  }

  public static func standard(homeDirectory: URL? = nil) -> PersonaPadStoragePaths {
    let resolvedHome = homeDirectory ?? FileClientProvider().fileClient.homeDirectory()
    let root = resolvedHome
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)
      .appendingPathComponent("PersonaPad", isDirectory: true)
    return PersonaPadStoragePaths(root: root)
  }
}

public enum PersonaPadStorage {
  public static func preferredPackDirectoryName(for pack: PackMeta) -> String {
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    let preferred = name.isEmpty ? id : name
    return sanitizePackDirectoryName(preferred)
  }

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

  public static func uniquePackDirectoryName(preferred: String, existing: Set<String>) -> String {
    let base = preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Pack" : preferred
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
