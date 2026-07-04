import Foundation

extension FileManager {
  /// Lists a PersonaKit pack directory without trusting the OS "hidden" determination.
  ///
  /// PersonaKit filters every pack scan by an explicit filename suffix (`.persona.json`,
  /// `.kit.json`, …), so `FileManager`'s `.skipsHiddenFiles` option buys nothing and
  /// actively harms robustness. On cloud-synced volumes — iCloud Drive, Dropbox,
  /// OneDrive — a file living inside a dot-prefixed root (such as `.personakit`) can
  /// carry a "hidden" attribute even though its own name is perfectly ordinary, and
  /// `.skipsHiddenFiles` then silently drops it. That is the observed hidden-root-on-iCloud
  /// failure: the entity files exist and read fine, but the enumeration returns empty.
  ///
  /// Instead of relying on sync-provider metadata, this enumerates every entry and
  /// excludes only genuine dotfiles and `._` AppleDouble sidecars by *name*. Real entity
  /// files never start with a dot, so they always survive; `.DS_Store` and `._foo`
  /// junk never do. The result is deterministic and independent of how — or whether — a
  /// volume marks items hidden.
  public func personaKitDirectoryContents(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]? = nil
  ) throws -> [URL] {
    try contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: keys,
      options: []
    )
    .filter { !$0.lastPathComponent.hasPrefix(".") }
  }
}
