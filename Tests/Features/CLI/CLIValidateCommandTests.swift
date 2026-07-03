import Foundation
import Testing

@testable import ContextCLI

struct CLIValidateCommandTests {
  @Test
  func validateRejectsPackPathWhenItIsAFile() throws {
    let root = try makeValidateRootWithPackFile(relativePath: "personas")

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "validate",
        "--root",
        root.path,
      ])
    }

    #expect(status == 1)
    #expect(stdoutOutput.contains("errors=1"))
    #expect(stdoutOutput.contains("persona file: Expected directory. expectedPath=Packs/personas"))
  }

  @Test
  func validateReportsResolvedScopesForExplicitRoot() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "validate",
        "--root",
        root.path,
      ])
    }

    #expect(status == 0)
    #expect(stdoutOutput.contains("Resolved scopes (project-only): project=\(root.path) global=(none)"))
    #expect(stdoutOutput.contains("Validation summary:"))
  }

  @Test
  func validateRejectsSessionsPathWhenItIsAFile() throws {
    let root = try makeValidateRootWithSessionsFile()

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "validate",
        "--root",
        root.path,
      ])
    }

    #expect(status == 1)
    #expect(stdoutOutput.contains("errors=1"))
    #expect(
      stdoutOutput.contains(
        "session sessionFile: Session discovery path is not a directory: Sessions. expectedPath=Sessions"
      )
    )
  }
}

private func makeValidateRootWithPackFile(relativePath: String) throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
  let packsURL = root.appendingPathComponent("Packs")
  try FileManager.default.createDirectory(
    at: packsURL,
    withIntermediateDirectories: true
  )
  try Data("not a directory".utf8).write(to: packsURL.appendingPathComponent(relativePath))

  return root
}

private func makeValidateRootWithSessionsFile() throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
  try copyFixtureKit(to: root)
  let sessionsURL = root.appendingPathComponent("Sessions")
  try FileManager.default.removeItem(at: sessionsURL)
  try Data("not a directory".utf8).write(to: sessionsURL)

  return root
}
