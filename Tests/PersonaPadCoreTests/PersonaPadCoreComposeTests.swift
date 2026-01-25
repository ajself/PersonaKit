import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreComposeTests: XCTestCase {
  func testComposeIncludesSystemAndSections() throws {
    let p = Persona(
      id: "t",
      name: "Test",
      system: "SYSTEM",
      template: PromptTemplate(
        format: nil,
        sections: [
          TemplateSection(key: "goal", label: "Goal", required: true)
        ])
    )

    let out = PromptComposer.compose(persona: p, sections: ["goal": "Ship v1"])
    XCTAssertTrue(out.contains("SYSTEM"))
    XCTAssertTrue(out.contains("GOAL"))
    XCTAssertTrue(out.contains("Ship v1"))
  }

  func testDeterministicComposeForExamplePackPersonas() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let result = PersonaLoader.loadDocument(from: packURL, sourceKind: .project)
    let set = try result.get()
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID

    let ids = ["senior-ios-engineer", "media-export-correctness"]
    let sectionsByID: [String: [String: String]] = [
      "senior-ios-engineer": [
        "context": "Repo: PersonaPad",
        "goal": "Verify deterministic prompt output",
        "constraints": "No behavior changes",
        "evidence": "Determinism tests",
        "task": "Review the output",
      ],
      "media-export-correctness": [
        "context": "Export pipeline v2",
        "evidence": "Timing drift in 120fps",
        "task": "Find deterministic pitfalls",
      ],
    ]

    for id in ids {
      guard let persona = resolved[id]?.persona else {
        XCTFail("Missing persona \(id)")
        continue
      }
      guard let sections = sectionsByID[id] else {
        XCTFail("Missing sections for \(id)")
        continue
      }
      let first = PromptComposer.compose(persona: persona, sections: sections)
      for _ in 0..<5 {
        let next = PromptComposer.compose(persona: persona, sections: sections)
        XCTAssertEqual(first, next)
      }
    }
  }

  func testResolvedJSONDeterministicEncoding() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let personaURL = coreTestsRepoRootURL().appendingPathComponent(
      "Examples/personapad.persona.json")

    let packSet = try PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get()
    let personaSet = try PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get()

    let packMap = Dictionary(uniqueKeysWithValues: packSet.personas.map { ($0.id, $0) })
    let resolvedPack = PersonaResolver.resolveAll(from: packMap).personasByID

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let personas: [Persona] = [
      resolvedPack["senior-ios-engineer"]?.persona,
      personaSet.personas.first,
    ].compactMap { $0 }

    XCTAssertEqual(personas.count, 2)

    for persona in personas {
      let firstData = try encoder.encode(persona)
      let firstText = String(data: firstData, encoding: .utf8)
      for _ in 0..<5 {
        let nextData = try encoder.encode(persona)
        let nextText = String(data: nextData, encoding: .utf8)
        XCTAssertEqual(firstText, nextText)
      }
    }
  }

  func testCLIOutputMatchesCorePrompt() throws {
    let packURL = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let set = try PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get()
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID
    guard let persona = resolved["senior-ios-engineer"]?.persona else {
      XCTFail("Missing persona")
      return
    }

    let sections = [
      "context": "Repo: PersonaPad",
      "goal": "Prove CLI parity",
      "constraints": "No divergence",
      "evidence": "Unit test",
      "task": "Compare outputs",
    ]

    let coreOutput = PromptComposer.compose(persona: persona, sections: sections)
    let cliOutput = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
    XCTAssertEqual(coreOutput, cliOutput)
  }

  func testCLIResolvedJSONMatchesCoreEncoding() throws {
    let personaURL = coreTestsRepoRootURL().appendingPathComponent(
      "Examples/personapad.persona.json")
    let set = try PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get()
    guard let persona = set.personas.first else {
      XCTFail("Missing persona")
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let coreText = String(data: try encoder.encode(persona), encoding: .utf8)
    let cliText = PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true)
    XCTAssertEqual(coreText, cliText)
  }
}
