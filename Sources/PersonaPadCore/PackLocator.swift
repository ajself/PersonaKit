import Foundation

public enum PersonaPackLocator {
  public static func builtInPackURLs(bundle: Bundle) -> [URL] {
    if let file = bundle.url(forResource: "BuiltIn.pack", withExtension: "json") {
      return [file]
    }
    if let dir = bundle.url(forResource: "BuiltIn", withExtension: nil) {
      return jsonFiles(in: dir)
    }
    return []
  }

  public static func builtInPackURLs(repoRoot: URL) -> [URL] {
    let resourcesRoot = repoRoot.appendingPathComponent("Sources/PersonaPadResources/Resources", isDirectory: true)
    let builtInDir = resourcesRoot.appendingPathComponent("BuiltIn", isDirectory: true)
    if FileManager.default.fileExists(atPath: builtInDir.path) {
      return jsonFiles(in: builtInDir)
    }
    let builtInFile = resourcesRoot.appendingPathComponent("BuiltIn.pack.json")
    if FileManager.default.fileExists(atPath: builtInFile.path) {
      return [builtInFile]
    }

    let legacyRoot = repoRoot.appendingPathComponent("Sources/PersonaPadApp/Resources", isDirectory: true)
    let legacyDir = legacyRoot.appendingPathComponent("BuiltIn", isDirectory: true)
    if FileManager.default.fileExists(atPath: legacyDir.path) {
      return jsonFiles(in: legacyDir)
    }
    let legacyFile = legacyRoot.appendingPathComponent("BuiltIn.pack.json")
    if FileManager.default.fileExists(atPath: legacyFile.path) {
      return [legacyFile]
    }
    return []
  }

  private static func jsonFiles(in directory: URL) -> [URL] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
      return []
    }
    return contents
      .filter { $0.pathExtension.lowercased() == "json" }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
  }
}
