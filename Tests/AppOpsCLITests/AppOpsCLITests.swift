import AppOpsCore
import Foundation
import PersonaKitCore
import Testing

@testable import AppOpsCLI

@Test
func runGeneratesReportAndMetrics() throws {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(
    UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  defer {
    try? fileManager.removeItem(at: root)
  }

  let builtInURL = root.appendingPathComponent("BuiltIn.pack.json")
  let leftURL = root.appendingPathComponent("Left.pack.json")
  let rightURL = root.appendingPathComponent("Right.pack.json")

  try writePack(
    to: builtInURL,
    packID: "built-in",
    packName: "Built In",
    personas: [
      (id: "alpha", name: "Alpha", system: "System A")
    ]
  )

  try writePack(
    to: leftURL,
    packID: "left",
    packName: "Left",
    personas: [
      (id: "alpha", name: "Alpha", system: "System A")
    ]
  )

  try writePack(
    to: rightURL,
    packID: "right",
    packName: "Right",
    personas: [
      (id: "alpha", name: "Alpha", system: "System A (modified)"),
      (id: "beta", name: "Beta", system: "System B"),
    ]
  )

  let environment = AppOpsEnvironment(
    fileClient: FileClient.liveValue,
    now: { Date(timeIntervalSince1970: 0) },
    repoRoot: { root },
    runCommand: { args in
      switch args.joined(separator: " ") {
      case "git rev-parse HEAD": return "deadbeef"
      case "swift --version": return "Swift 6.2"
      case "xcodebuild -version": return "Xcode 16.0"
      default: return nil
      }
    },
    builtInPackURLs: { _ in [builtInURL] }
  )

  let outputDir = root.appendingPathComponent("Artifacts", isDirectory: true)
  let args = [
    "--out-dir", outputDir.path,
    "--import-source", rightURL.path,
    "--diff-left", leftURL.path,
    "--diff-right", rightURL.path,
    "--no-user-packs",
  ]

  let result = try AppOpsCLI.run(arguments: args, environment: environment)

  #expect(result.report.reload.totalPacks == 1)
  #expect(result.report.reload.totalPersonas == 1)
  #expect(result.report.diff.addedCount == 1)
  #expect(result.report.diff.modifiedCount == 1)
  #expect(result.report.importMetrics.filesCopied == 1)
  #expect(result.report.exportMetrics.bytesWritten > 0)

  let markdownURL = result.outputRoot.appendingPathComponent("REPORT.md")
  let jsonURL = result.outputRoot.appendingPathComponent("report.json")
  #expect(fileManager.fileExists(atPath: markdownURL.path))
  #expect(fileManager.fileExists(atPath: jsonURL.path))
}

private func writePack(
  to url: URL,
  packID: String,
  packName: String,
  personas: [(id: String, name: String, system: String)]
) throws {
  let personaJSON = personas.map { persona in
    """
    {
      "id": "\(escapeJSON(persona.id))",
      "name": "\(escapeJSON(persona.name))",
      "system": "\(escapeJSON(persona.system))"
    }
    """
  }.joined(separator: ",\n")

  let json = """
    {
      "schemaVersion": 1,
      "documentType": "personaPack",
      "pack": {
        "id": "\(escapeJSON(packID))",
        "name": "\(escapeJSON(packName))"
      },
      "personas": [
        \(personaJSON)
      ]
    }
    """

  guard let data = json.data(using: .utf8) else {
    throw AppOpsTestError("Failed to encode pack JSON.")
  }
  try data.write(to: url, options: .atomic)
}

private func escapeJSON(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

private struct AppOpsTestError: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String { message }
}
