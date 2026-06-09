import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct ListCommandTests {
  @Test
  func listPersonas() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .personas)

    let expected = "solo-developer — Solo Developer"

    #expect(output == expected)
  }

  @Test
  func listEssentials() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .essentials)

    let expected = "contract-boundaries"

    #expect(output == expected)
  }

  @Test
  func cliListPersonasRejectsPackPathWhenItIsAFile() throws {
    let root = try makeRootWithPackFile(relativePath: "personas")

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "list",
        "--root",
        root.path,
        "personas",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Packs/personas"))
    #expect(stderrOutput.contains("Expected directory."))
  }

  @Test
  func cliListEssentialsRejectsEssentialPathWhenItIsAFile() throws {
    let root = try makeRootWithPackFile(relativePath: "essentials")

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "list",
        "--root",
        root.path,
        "essentials",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Essentials path is not a directory"))
  }

  @Test
  func listReferences() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .references)

    let expected = "cli-change-checklist — CLI Change Checklist"

    #expect(output == expected)
  }

  @Test
  func listSessions() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)
    try writeSession(
      root: root,
      session: SessionFile(
        id: "review-swiftui",
        personaId: "solo-developer",
        directiveId: "small-cli-change",
        kitOverrides: ["cli-guardrails"]
      )
    )

    let output = try ListCommand.list(root: root, entityType: .sessions)

    let expected = [
      "review-swiftui — solo-developer / small-cli-change [kits: cli-guardrails]",
      "solo-dev — solo-developer / small-cli-change",
    ].joined(separator: "\n")

    #expect(output == expected)
  }

  @Test
  func listSessionsPrefersProjectScopeForDuplicateIDs() throws {
    let tempRoot = try makeTempDirectory()
    let projectRoot = tempRoot.appendingPathComponent("Project/.personakit")
    let globalRoot = tempRoot.appendingPathComponent("Global/.personakit")

    try PersonaKitInitializer().run(destination: projectRoot.path)
    try PersonaKitInitializer().run(destination: globalRoot.path)

    try writeSession(
      root: globalRoot,
      session: SessionFile(
        id: "shared-review",
        personaId: "solo-developer",
        directiveId: "small-cli-change",
        kitOverrides: nil
      )
    )
    try writeSession(
      root: projectRoot,
      session: SessionFile(
        id: "shared-review",
        personaId: "solo-developer",
        directiveId: "small-cli-change",
        kitOverrides: nil
      )
    )

    let scopes = ScopeSet(
      projectScopeURL: projectRoot,
      globalScopeURL: globalRoot
    )

    let output = try ListCommand.list(scopes: scopes, entityType: .sessions)

    let expected = [
      "shared-review — solo-developer / small-cli-change",
      "solo-dev — solo-developer / small-cli-change",
    ].joined(separator: "\n")

    #expect(output == expected)
  }

  @Test
  func cliListSessionsRejectsSessionsPathWhenItIsAFile() throws {
    let root = try makeRootWithSessionsFile()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "list",
        "--root",
        root.path,
        "sessions",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Session discovery path is not a directory: Sessions."))
  }
}

private func makeRootWithPackFile(relativePath: String) throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
  let packsURL = root.appendingPathComponent("Packs")
  try FileManager.default.createDirectory(
    at: packsURL,
    withIntermediateDirectories: true
  )
  try Data("not a directory".utf8).write(to: packsURL.appendingPathComponent(relativePath))

  return root
}

private func makeRootWithSessionsFile() throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")

  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("Packs"),
    withIntermediateDirectories: true
  )
  try Data("not a directory".utf8).write(to: root.appendingPathComponent("Sessions"))

  return root
}

private func writeSession(root: URL, session: SessionFile) throws {
  let sessionsURL = root.appendingPathComponent("Sessions", isDirectory: true)
  try FileManager.default.createDirectory(
    at: sessionsURL,
    withIntermediateDirectories: true
  )

  let fileURL = sessionsURL.appendingPathComponent("\(session.id).session.json")
  let data = try JSONEncoder().encode(session)
  try data.write(to: fileURL)
}
