import Foundation

/// Decides which owners refresh after an external file change.
///
/// A `nil` change set means an explicit reload (open, save, connect), which always counts as
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

  private static func canonicalPath(_ url: URL) -> String {
    let path = url.resolvingSymlinksInPath().standardizedFileURL.path

    guard path.count > 1, path.hasSuffix("/") else {
      return path
    }

    return String(path.dropLast())
  }
}
