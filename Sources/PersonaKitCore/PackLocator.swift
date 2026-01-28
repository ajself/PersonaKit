import Dependencies
import Foundation

/// Locates built-in persona packs in bundles or repo layouts.
public enum PersonaPackLocator {
  /// Returns built-in pack URLs from a resource bundle.
  public static func builtInPackURLs(bundle: Bundle) -> [URL] {
    @Dependency(\.fileClient) var fileClient
    if let file = bundle.url(forResource: "BuiltIn.pack", withExtension: "json") {
      return [file]
    }
    if let dir = bundle.url(forResource: "BuiltIn", withExtension: nil) {
      return jsonFiles(in: dir, fileClient: fileClient)
    }
    return []
  }

  /// Returns built-in pack URLs from a repo checkout on disk.
  public static func builtInPackURLs(repoRoot: URL) -> [URL] {
    @Dependency(\.fileClient) var fileClient
    let resourcesRoot = repoRoot.appendingPathComponent(
      "Sources/PersonaKitResources/Resources", isDirectory: true)
    let builtInDir = resourcesRoot.appendingPathComponent("BuiltIn", isDirectory: true)
    if fileClient.fileExists(builtInDir) {
      return jsonFiles(in: builtInDir, fileClient: fileClient)
    }
    let builtInFile = resourcesRoot.appendingPathComponent("BuiltIn.pack.json")
    if fileClient.fileExists(builtInFile) {
      return [builtInFile]
    }

    let legacyRoot = repoRoot.appendingPathComponent(
      "Sources/PersonaKitApp/Resources", isDirectory: true)
    let legacyDir = legacyRoot.appendingPathComponent("BuiltIn", isDirectory: true)
    if fileClient.fileExists(legacyDir) {
      return jsonFiles(in: legacyDir, fileClient: fileClient)
    }
    let legacyFile = legacyRoot.appendingPathComponent("BuiltIn.pack.json")
    if fileClient.fileExists(legacyFile) {
      return [legacyFile]
    }
    return []
  }

  private static func jsonFiles(in directory: URL, fileClient: FileClient) -> [URL] {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      return []
    }
    return
      contents
      .filter { $0.pathExtension.lowercased() == "json" }
      .sorted {
        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
      }
  }
}
