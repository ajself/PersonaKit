import Dependencies
import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Loader")
struct PersonaPadCoreLoaderTests {
  struct StubError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  @Test("Load documents warns on directory read failure")
  func loadDocumentsWarnsOnDirectoryReadFailure() {
    var fileClient = FileClient.liveValue
    fileClient.contentsOfDirectory = { _, _ in
      throw StubError(message: "nope")
    }

    let directory = URL(fileURLWithPath: "/tmp/missing")
    let result = withDependencies {
      $0.fileClient = fileClient
    } operation: {
      PersonaLoader.loadDocuments(in: directory, sourceKind: .project)
    }

    #expect(result.sets.isEmpty)
    #expect(
      result.diagnostics.contains {
        $0.severity == .warning && $0.message.contains("Could not read directory")
      }
    )
    #expect(result.diagnostics.contains { $0.message.contains("nope") })
  }

  @Test("Load documents sorts JSON files deterministically")
  func loadDocumentsSortsJSONFilesDeterministically() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let fileNames = ["b.persona.json", "a.persona.json", "c.persona.json"]
    for name in fileNames {
      let url = root.appendingPathComponent(name)
      let id = url.deletingPathExtension().deletingPathExtension().lastPathComponent
      let json = """
        {
          "schemaVersion": 1,
          "documentType": "persona",
          "persona": { "id": "\(id)", "name": "\(id)", "system": "SYSTEM" }
        }
        """
      try json.write(to: url, atomically: true, encoding: .utf8)
    }
    try "ignore".write(
      to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

    let result = PersonaLoader.loadDocuments(in: root, sourceKind: .project)
    let names = result.sets.compactMap { $0.source.url?.lastPathComponent }
    #expect(names == ["a.persona.json", "b.persona.json", "c.persona.json"])
  }

  @Test("Pack locator sorts built-in JSON files deterministically")
  func packLocatorSortsBuiltInJSONFilesDeterministically() {
    let repoRoot = URL(fileURLWithPath: "/tmp/repo")
    let builtInDir = repoRoot.appendingPathComponent(
      "Sources/PersonaPadResources/Resources/BuiltIn", isDirectory: true)

    var fileClient = FileClient.liveValue
    fileClient.fileExists = { url in
      url.standardizedFileURL == builtInDir.standardizedFileURL
    }
    fileClient.contentsOfDirectory = { url, _ in
      guard url.standardizedFileURL == builtInDir.standardizedFileURL else { return [] }
      return [
        builtInDir.appendingPathComponent("z.json"),
        builtInDir.appendingPathComponent("a.json"),
        builtInDir.appendingPathComponent("notes.txt"),
      ]
    }

    let urls = withDependencies {
      $0.fileClient = fileClient
    } operation: {
      PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }

    #expect(urls.map(\.lastPathComponent) == ["a.json", "z.json"])
  }
}
