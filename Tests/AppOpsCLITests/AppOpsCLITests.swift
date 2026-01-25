import AppOpsCore
import Foundation
import PersonaKitCore
import Testing

@testable import AppOpsCLI

@Test
func runGeneratesReportAndMetrics() throws {
  let fileManager = FileManager.default
  let root = try makeTempRoot(fileManager: fileManager)
  defer { try? fileManager.removeItem(at: root) }

  let packURLs = PackURLs(root: root)
  try writePack(
    to: packURLs.builtIn,
    packID: "built-in",
    packName: "Built In",
    personas: [
      PersonaSeed(id: "alpha", name: "Alpha", system: "System A")
    ]
  )
  try writePack(
    to: packURLs.left,
    packID: "left",
    packName: "Left",
    personas: [
      PersonaSeed(id: "alpha", name: "Alpha", system: "System A")
    ]
  )
  try writePack(
    to: packURLs.right,
    packID: "right",
    packName: "Right",
    personas: [
      PersonaSeed(id: "alpha", name: "Alpha", system: "System A (modified)"),
      PersonaSeed(id: "beta", name: "Beta", system: "System B"),
    ]
  )

  let environment = makeEnvironment(root: root, builtInURL: packURLs.builtIn)
  let outputDir = root.appendingPathComponent("Artifacts", isDirectory: true)
  let args = makeArgs(outputDir: outputDir, leftURL: packURLs.left, rightURL: packURLs.right)
  let result = try AppOpsCLI.run(arguments: args, environment: environment)

  assertReportMetrics(result.report)
  assertOutputFiles(result.outputRoot, fileManager: fileManager)
}

private func makeTempRoot(fileManager: FileManager) throws -> URL {
  let root = fileManager.temporaryDirectory.appendingPathComponent(
    UUID().uuidString,
    isDirectory: true
  )
  try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  return root
}

private func makeEnvironment(root: URL, builtInURL: URL) -> AppOpsEnvironment {
  AppOpsEnvironment(
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
}

private func makeArgs(outputDir: URL, leftURL: URL, rightURL: URL) -> [String] {
  [
    "--out-dir", outputDir.path,
    "--import-source", rightURL.path,
    "--diff-left", leftURL.path,
    "--diff-right", rightURL.path,
    "--no-user-packs",
    "--no-build-run",
  ]
}

private func assertReportMetrics(_ report: AppOpsReport) {
  #expect(report.reload.totalPacks == 1)
  #expect(report.reload.totalPersonas == 1)
  #expect(report.diff.addedCount == 1)
  #expect(report.diff.modifiedCount == 1)
  #expect(report.importMetrics.filesCopied == 1)
  #expect(report.exportMetrics.bytesWritten > 0)
  #expect(report.buildRun == nil)
  #expect(report.buildRunSkippedReason == "disabled via --no-build-run")
}

private func assertOutputFiles(_ outputRoot: URL, fileManager: FileManager) {
  let markdownURL = outputRoot.appendingPathComponent("REPORT.md")
  let jsonURL = outputRoot.appendingPathComponent("report.json")
  #expect(fileManager.fileExists(atPath: markdownURL.path))
  #expect(fileManager.fileExists(atPath: jsonURL.path))
}

private func writePack(
  to url: URL,
  packID: String,
  packName: String,
  personas: [PersonaSeed]
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

private struct PackURLs {
  let builtIn: URL
  let left: URL
  let right: URL

  init(root: URL) {
    builtIn = root.appendingPathComponent("BuiltIn.pack.json")
    left = root.appendingPathComponent("Left.pack.json")
    right = root.appendingPathComponent("Right.pack.json")
  }
}

private struct PersonaSeed {
  let id: String
  let name: String
  let system: String
}

private struct AppOpsTestError: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String { message }
}
