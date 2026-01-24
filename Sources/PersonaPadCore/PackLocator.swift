import Foundation

public enum PersonaPackLocator {
  public static func builtInPackURLs(bundle: Bundle) -> [URL] {
    if let file = bundle.url(forResource: "BuiltIn.pack", withExtension: "json") {
      return [file]
    }
    if let dir = bundle.url(forResource: "BuiltIn", withExtension: nil) {
      return jsonFiles(in: dir, fileClient: FileClientProvider().fileClient)
    }
    return []
  }

  public static func builtInPackURLs(repoRoot: URL) -> [URL] {
    let fileClient = FileClientProvider().fileClient
    let resourcesRoot = repoRoot.appendingPathComponent("Sources/PersonaPadResources/Resources", isDirectory: true)
    let builtInDir = resourcesRoot.appendingPathComponent("BuiltIn", isDirectory: true)
    if fileClient.fileExists(builtInDir) {
      return jsonFiles(in: builtInDir, fileClient: fileClient)
    }
    let builtInFile = resourcesRoot.appendingPathComponent("BuiltIn.pack.json")
    if fileClient.fileExists(builtInFile) {
      return [builtInFile]
    }

    let legacyRoot = repoRoot.appendingPathComponent("Sources/PersonaPadApp/Resources", isDirectory: true)
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
    return contents
      .filter { $0.pathExtension.lowercased() == "json" }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
  }
}
