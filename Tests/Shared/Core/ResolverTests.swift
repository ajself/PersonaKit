import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct ResolverTests {
  @Test
  func resolveHappyPath() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    let registry = try Registry.load(root: root)

    let definition = SessionDefinition(
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: nil
    )

    let session = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

    #expect(session.persona.id == "senior-swiftui-engineer")
    #expect(session.directive.id == "apply-style")
    #expect(
      session.kits.map { $0.id } == ["repo-constraints", "swift-style", "swiftui-style"]
    )
    #expect(session.skills.map { $0.id } == ["codex-cli"])
    #expect(
      session.availableGroundingSkills.map(\.id) == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
  }

  @Test
  func missingKitIdError() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let personaURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    let data = try Data(contentsOf: personaURL)
    let persona = try JSONDecoder().decode(Persona.self, from: data)
    let updatedPersona = Persona(
      id: persona.id,
      version: persona.version,
      name: persona.name,
      summary: persona.summary,
      responsibilities: persona.responsibilities,
      values: persona.values,
      nonGoals: persona.nonGoals,
      defaultKitIds: ["missing-kit"],
      allowedSkillIds: persona.allowedSkillIds,
      forbiddenSkillIds: persona.forbiddenSkillIds
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(updatedPersona).write(to: personaURL)

    let registry = try Registry.load(root: root)
    let definition = SessionDefinition(
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: nil
    )

    do {
      _ = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)
      #expect(Bool(false))
    } catch let error as ResolverResolutionError {
      #expect(
        error.errors == [
          .missingKitId(
            sourceType: .persona,
            sourceId: "senior-swiftui-engineer",
            field: "defaultKitIds",
            missingId: "missing-kit"
          )
        ]
      )
    }
  }

  @Test
  func deterministicOrdering() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    let registry = try Registry.load(root: root)

    let definition = SessionDefinition(
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: nil
    )

    let session = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

    #expect(session.kits.map { $0.id } == session.kits.map { $0.id }.sorted())
    #expect(session.skills.map { $0.id } == session.skills.map { $0.id }.sorted())
    #expect(
      session.availableGroundingSkills.map(\.id) == session.availableGroundingSkills.map(\.id).sorted()
    )
  }
}
