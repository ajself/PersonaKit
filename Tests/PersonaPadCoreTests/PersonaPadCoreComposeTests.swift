import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Compose")
struct PersonaPadCoreComposeTests {
  @Test("Compose includes system and sections")
  func composeIncludesSystemAndSections() throws {
    let persona = Persona(
      id: "t",
      name: "Test",
      system: "SYSTEM",
      template: PromptTemplate(
        format: nil,
        sections: [
          TemplateSection(key: "goal", label: "Goal", required: true)
        ])
    )

    let out = PromptComposer.compose(persona: persona, sections: ["goal": "Ship v1"])
    #expect(out.contains("SYSTEM"))
    #expect(out.contains("GOAL"))
    #expect(out.contains("Ship v1"))
  }

  @Test("Deterministic compose for example pack personas")
  func deterministicComposeForExamplePackPersonas() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let result = PersonaLoader.loadDocument(from: packURL, sourceKind: .project)
    let set = try #require(try? result.get())
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID

    let ids = ["senior-ios-engineer", "media-export-correctness"]
    var sectionsByID: [String: [String: String]] = [:]

    var seniorSections: [String: String] = [:]
    seniorSections["context"] = "Repo: PersonaPad"
    seniorSections["goal"] = "Verify deterministic prompt output"
    seniorSections["constraints"] = "No behavior changes"
    seniorSections["evidence"] = "Determinism tests"
    seniorSections["task"] = "Review the output"
    sectionsByID["senior-ios-engineer"] = seniorSections

    var exportSections: [String: String] = [:]
    exportSections["context"] = "Export pipeline v2"
    exportSections["evidence"] = "Timing drift in 120fps"
    exportSections["task"] = "Find deterministic pitfalls"
    sectionsByID["media-export-correctness"] = exportSections

    for id in ids {
      let persona = try #require(resolved[id]?.persona)
      let sections = try #require(sectionsByID[id])
      let first = PromptComposer.compose(persona: persona, sections: sections)
      for _ in 0..<5 {
        let next = PromptComposer.compose(persona: persona, sections: sections)
        #expect(first == next)
      }
    }
  }

  @Test("Resolved JSON deterministic encoding")
  func resolvedJSONDeterministicEncoding() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let personaURL = coreTestsRepoRootURL().appendingPathComponent(
      "Examples/personapad.persona.json")

    let packSet = try #require(
      try? PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get())
    let personaSet = try #require(
      try? PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get())

    let packMap = Dictionary(uniqueKeysWithValues: packSet.personas.map { ($0.id, $0) })
    let resolvedPack = PersonaResolver.resolveAll(from: packMap).personasByID

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let personas = [resolvedPack["senior-ios-engineer"]?.persona, personaSet.personas.first]
      .compactMap { $0 }

    #expect(personas.count == 2)

    for persona in personas {
      let firstData = try encoder.encode(persona)
      let firstText = try #require(String(data: firstData, encoding: .utf8))
      for _ in 0..<5 {
        let nextData = try encoder.encode(persona)
        let nextText = try #require(String(data: nextData, encoding: .utf8))
        #expect(firstText == nextText)
      }
    }
  }

  @Test("CLI output matches core prompt")
  func cliOutputMatchesCorePrompt() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let set = try #require(
      try? PersonaLoader
        .loadDocument(from: packURL, sourceKind: .project)
        .get()
    )
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID
    let persona = try #require(resolved["senior-ios-engineer"]?.persona)

    var sections: [String: String] = [:]
    sections["context"] = "Repo: PersonaPad"
    sections["goal"] = "Prove CLI parity"
    sections["constraints"] = "No divergence"
    sections["evidence"] = "Unit test"
    sections["task"] = "Compare outputs"

    let coreOutput = PromptComposer.compose(persona: persona, sections: sections)
    let cliOutput = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
    #expect(coreOutput == cliOutput)
  }

  @Test("CLI resolved JSON matches core encoding")
  func cliResolvedJSONMatchesCoreEncoding() throws {
    let personaURL = coreTestsRepoRootURL().appendingPathComponent(
      "Examples/personapad.persona.json")
    let set = try #require(
      try? PersonaLoader
        .loadDocument(from: personaURL, sourceKind: .project)
        .get()
    )
    let persona = try #require(set.personas.first)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let coreText = try #require(String(data: try encoder.encode(persona), encoding: .utf8))
    let cliText = try #require(
      PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true)
    )
    #expect(coreText == cliText)
  }
}
