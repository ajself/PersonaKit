import Foundation

/// Directory helpers for canonical PersonaKit root subpaths.
public struct PersonaKitDirectory {
  private static let packsDirectoryName = "Packs"
  private static let sessionsDirectoryName = "Sessions"

  /// Returns `root/Packs`.
  ///
  /// - Parameter root: PersonaKit root directory URL.
  /// - Returns: URL for the `Packs` directory under `root`.
  public static func packsURL(root: URL) -> URL {
    root.appendingPathComponent(packsDirectoryName)
  }

  /// Returns `root/Sessions`.
  ///
  /// - Parameter root: PersonaKit root directory URL.
  /// - Returns: URL for the `Sessions` directory under `root`.
  public static func sessionsURL(root: URL) -> URL {
    root.appendingPathComponent(sessionsDirectoryName)
  }

  /// Returns `root/Packs/skills`.
  ///
  /// - Parameter root: PersonaKit root directory URL.
  /// - Returns: URL for the `Packs/skills` directory under `root`.
  public static func skillsURL(root: URL) -> URL {
    packsURL(root: root).appendingPathComponent("skills")
  }

  /// Returns whether `root/Packs` exists and is a directory.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory URL.
  ///   - fileManager: File manager used for existence checks.
  /// - Returns: `true` when `root/Packs` exists and is a directory.
  public static func hasPacks(root: URL, fileManager: FileManager = .default) -> Bool {
    hasDirectory(at: packsURL(root: root), fileManager: fileManager)
  }

  /// Returns whether `root/Sessions` exists and is a directory.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory URL.
  ///   - fileManager: File manager used for existence checks.
  /// - Returns: `true` when `root/Sessions` exists and is a directory.
  public static func hasSessions(root: URL, fileManager: FileManager = .default) -> Bool {
    hasDirectory(at: sessionsURL(root: root), fileManager: fileManager)
  }

  private static func hasDirectory(at url: URL, fileManager: FileManager) -> Bool {
    var isDirectory: ObjCBool = false

    return fileManager.fileExists(
      atPath: url.path,
      isDirectory: &isDirectory
    ) && isDirectory.boolValue
  }
}
