import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct RegistryTests {
  @Test
  func registryLoadsStarterKit() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: destination.path)

    let registry = try Registry.load(root: destination)

    #expect(registry.personas.map(\.id) == ["solo-developer"])
    #expect(registry.kits.map(\.id) == ["v1-cli-guardrails"])
    #expect(registry.directives.map(\.id) == ["small-cli-change"])
    #expect(registry.intentTemplates.map(\.id) == [])
    #expect(registry.skills.map(\.id) == ["autonomous-agent-loop", "opencode-cli"])
  }

  @Test
  func registryDetectsDuplicateIDs() throws {
    let root = try makeTempDirectory()
    let packs = root.appendingPathComponent("Packs/personas")
    try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)

    let personaJSON = """
      {
        \"id\": \"duplicate-persona\",
        \"version\": \"1.0\",
        \"name\": \"Duplicate Persona\",
        \"summary\": \"Testing duplicates\",
        \"responsibilities\": [],
        \"values\": [],
        \"nonGoals\": [],
        \"defaultKitIds\": [],
        \"allowedSkillIds\": [],
        \"forbiddenSkillIds\": []
      }
      """

    try Data(personaJSON.utf8).write(to: packs.appendingPathComponent("alpha.persona.json"))
    try Data(personaJSON.utf8).write(to: packs.appendingPathComponent("beta.persona.json"))

    do {
      _ = try Registry.load(root: root)
      #expect(Bool(false))
    } catch let error as RegistryLoadError {
      #expect(error.errors.count == 1)
      let first = error.errors[0]
      #expect(first.entityType == .persona)
      #expect(first.id == "duplicate-persona")
      #expect(first.relativePath == "Packs/personas/beta.persona.json")
      #expect(first.message == "Duplicate id \"duplicate-persona\".")
    }
  }

  @Test
  func registryFailsOnMissingPacksDirectory() throws {
    let root = try makeTempDirectory()

    do {
      _ = try Registry.load(root: root)
      #expect(Bool(false))
    } catch let error as RegistryLoadError {
      #expect(error.errors.count == 1)
      let first = error.errors[0]
      #expect(first.entityType == .packsRoot)
      #expect(first.relativePath == "Packs")
      #expect(first.message == "Missing Packs directory.")
    }
  }
}
