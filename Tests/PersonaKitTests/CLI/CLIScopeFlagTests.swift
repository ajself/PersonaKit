import Foundation
import Testing

@testable import PersonaKitCore

struct CLIScopeFlagTests {
  @Test
  func rootBypassesScopes() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")
    let overrideRoot = try makeTempDirectory().appendingPathComponent("OverrideKit")

    try writePersona(id: "project-persona", name: "Project Persona", root: projectScope)
    try writePersona(id: "global-persona", name: "Global Persona", root: globalScope)
    try writePersona(id: "root-persona", name: "Root Persona", root: overrideRoot)

    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "--root",
        overrideRoot.path,
        "personas",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("root-persona"))
    #expect(!output.contains("project-persona"))
    #expect(!output.contains("global-persona"))
  }

  @Test
  func noProjectDisablesProjectScope() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writePersona(id: "project-persona", name: "Project Persona", root: projectScope)
    try writePersona(id: "global-persona", name: "Global Persona", root: globalScope)

    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "--no-project",
        "personas",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("global-persona"))
    #expect(!output.contains("project-persona"))
  }

  @Test
  func noGlobalDisablesGlobalScope() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writePersona(id: "project-persona", name: "Project Persona", root: projectScope)
    try writePersona(id: "global-persona", name: "Global Persona", root: globalScope)

    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "--no-global",
        "personas",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("project-persona"))
    #expect(!output.contains("global-persona"))
  }
}

private func writePersona(id: String, name: String, root: URL) throws {
  let directory = root.appendingPathComponent("Packs/personas")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      \"id\": \"\(id)\",
      \"version\": \"1.0\",
      \"name\": \"\(name)\",
      \"summary\": \"Summary\",
      \"responsibilities\": [],
      \"values\": [],
      \"nonGoals\": [],
      \"defaultKitIds\": [],
      \"allowedSkillIds\": [],
      \"forbiddenSkillIds\": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).persona.json"))
}
