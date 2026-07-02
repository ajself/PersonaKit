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
    #expect(session.intents.map { $0.id } == ["swift-refactor-safe"])
    #expect(session.skills.map { $0.id } == ["codex-cli"])
    #expect(
      session.availableReferences.map(\.id) == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
      ]
    )
    #expect(
      session.essentials.map { $0.id } == [
        "persona-activation-contract",
        "skill-authorization-contract",
        "environment",
        "non-goals",
        "swift-style-guide",
        "swiftui-style-guide",
        "tools-and-constraints",
      ]
    )
    let contract = try #require(
      session.essentials.first(where: { $0.id == SystemEssentials.personaActivationContractId })
    )
    #expect(contract.source == .systemBuiltIn)
    #expect(contract.content?.contains("One active operating persona") == true)
    let skillContract = try #require(
      session.essentials.first(where: { $0.id == SystemEssentials.skillAuthorizationContractId })
    )
    #expect(skillContract.source == .systemBuiltIn)
    #expect(skillContract.content?.contains("Only PersonaKit-declared skills are authorized") == true)
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
  func missingEssentialFileError() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let missingURL = root.appendingPathComponent("Packs/essentials/swiftui-style-guide.md")
    try FileManager.default.removeItem(at: missingURL)

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
          .missingEssentialFile(
            sourceType: .kit,
            sourceId: "swiftui-style",
            field: "essentialIds",
            missingId: "swiftui-style-guide",
            expectedPath: "Packs/essentials/swiftui-style-guide.md"
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
    #expect(session.intents.map { $0.id } == session.intents.map { $0.id }.sorted())
    #expect(session.skills.map { $0.id } == session.skills.map { $0.id }.sorted())
    #expect(
      session.availableReferences.map(\.id) == session.availableReferences.map(\.id).sorted()
    )
    #expect(
      session.essentials.map { $0.id } == [
        "persona-activation-contract",
        "skill-authorization-contract",
        "environment",
        "non-goals",
        "swift-style-guide",
        "swiftui-style-guide",
        "tools-and-constraints",
      ]
    )
  }

  @Test
  func requiredPersonaActivationContractIsDeduplicatedWhenExplicitlyIncluded() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let kitURL = root.appendingPathComponent("Packs/kits/repo-constraints.kit.json")
    let data = try Data(contentsOf: kitURL)
    let kit = try JSONDecoder().decode(Kit.self, from: data)
    let updatedKit = Kit(
      id: kit.id,
      version: kit.version,
      name: kit.name,
      summary: kit.summary,
      essentialIds: kit.essentialIds + [SystemEssentials.personaActivationContractId],
      intentTemplateIds: kit.intentTemplateIds,
      skillIds: kit.skillIds
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(updatedKit).write(to: kitURL)

    let registry = try Registry.load(root: root)
    let definition = SessionDefinition(
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: nil
    )

    let session = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

    #expect(
      session.essentials.map(\.id).filter { $0 == SystemEssentials.personaActivationContractId }.count
        == 1
    )
  }

  @Test
  func projectOverrideReplacesBuiltInPersonaActivationContract() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let overrideURL = root.appendingPathComponent(
      "Packs/essentials/\(SystemEssentials.personaActivationContractId).md"
    )
    try "# Project Override\n".write(to: overrideURL, atomically: true, encoding: .utf8)

    let registry = try Registry.load(root: root)
    let session = try Resolver.resolve(
      definition: SessionDefinition(
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      ),
      registry: registry,
      rootURL: root
    )

    let contract = try #require(
      session.essentials.first(where: { $0.id == SystemEssentials.personaActivationContractId })
    )
    #expect(contract.source == .file)
    #expect(contract.content == nil)
    #expect(contract.url.standardizedFileURL.path == overrideURL.standardizedFileURL.path)
  }

  @Test
  func globalOnlyOverrideDoesNotReplaceProjectBuiltInContract() throws {
    let root = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = try makeTempDirectory().appendingPathComponent(".personakit")

    try copyFixtureKit(to: projectScope)
    try copyFixtureKit(to: globalScope)

    let globalOverrideURL = globalScope.appendingPathComponent(
      "Packs/essentials/\(SystemEssentials.personaActivationContractId).md"
    )
    try "# Global Override\n".write(to: globalOverrideURL, atomically: true, encoding: .utf8)

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let session = try Resolver.resolve(
      definition: SessionDefinition(
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      ),
      registry: registry,
      scopes: scopes
    )

    let contract = try #require(
      session.essentials.first(where: { $0.id == SystemEssentials.personaActivationContractId })
    )
    #expect(contract.source == .systemBuiltIn)
    #expect(contract.content?.contains("One active operating persona") == true)
    #expect(contract.url.standardizedFileURL.path != globalOverrideURL.standardizedFileURL.path)
  }
}
