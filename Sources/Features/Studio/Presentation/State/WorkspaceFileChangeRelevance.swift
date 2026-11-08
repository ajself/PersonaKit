import Foundation

/// Decides which owners refresh after an external file change.
///
/// A `nil` change set means an explicit reload (open, save), which always counts as
/// relevant. Matching errs toward refreshing: a same-named file in another scope, or a
/// changed parent directory (FSEvents coalesces to directories when it drops events), also
/// counts as a match.
enum WorkspaceFileChangeRelevance {
  /// Drops changes no Studio surface reads, such as Finder metadata.
  static func meaningfulChanges(_ changedFileURLs: some Sequence<URL>) -> Set<URL> {
    Set(changedFileURLs.filter { $0.lastPathComponent != ".DS_Store" })
  }

  /// A session preview depends on everything it resolves from, so any change counts except
  /// edits to other sessions' files.
  static func affectsSession(
    fileURL sessionFileURL: URL,
    changedFileURLs: Set<URL>?
  ) -> Bool {
    guard let changedFileURLs else {
      return true
    }

    return changedFileURLs.contains { changedURL in
      !isSessionFile(changedURL) || matches(changedURL, fileURL: sessionFileURL)
    }
  }

  static func affectsFile(
    _ fileURL: URL,
    changedFileURLs: Set<URL>?
  ) -> Bool {
    guard let changedFileURLs else {
      return true
    }

    return changedFileURLs.contains { matches($0, fileURL: fileURL) }
  }

  private static func isSessionFile(_ url: URL) -> Bool {
    url.lastPathComponent.hasSuffix(".session.json")
  }

  private static func matches(
    _ changedURL: URL,
    fileURL: URL
  ) -> Bool {
    if changedURL.lastPathComponent == fileURL.lastPathComponent {
      return true
    }

    let changedPath = canonicalPath(changedURL)
    let filePath = canonicalPath(fileURL)

    return filePath == changedPath || filePath.hasPrefix(changedPath + "/")
  }

  /// Resolves symlinks through the deepest part of the path that still exists. Foundation resolves only an
  /// existing path, so a deleted file seen through a symlinked workspace would otherwise never match the real
  /// directory FSEvents reports.
  private static func canonicalPath(_ url: URL) -> String {
    var existingURL = url.standardizedFileURL
    var missingComponents: [String] = []

    while existingURL.pathComponents.count > 1,
      !FileManager.default.fileExists(atPath: existingURL.path)
    {
      missingComponents.insert(existingURL.lastPathComponent, at: 0)
      existingURL.deleteLastPathComponent()
    }

    var resolvedURL = existingURL.resolvingSymlinksInPath()
    for component in missingComponents {
      resolvedURL.appendPathComponent(component)
    }

    return resolvedURL.standardizedFileURL.path
  }
}
