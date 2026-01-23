import XCTest
@testable import PersonaPadCore

final class PersonaPadCoreTests: XCTestCase {
  private func repoRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  func testDecodePackExample() throws {
    let url = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    switch result {
    case .success(let set):
      XCTAssertEqual(set.pack.id, "com.afterimage.devpack")
      XCTAssertEqual(set.personas.count, 2)
    case .failure(let error):
      XCTFail("Failed to decode pack example: \(error.diagnostics)")
    }
  }

  func testDecodePersonaExample() throws {
    let url = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    switch result {
    case .success(let set):
      XCTAssertEqual(set.personas.count, 1)
      XCTAssertEqual(set.personas.first?.id, "debug-triage")
    case .failure(let error):
      XCTFail("Failed to decode persona example: \(error.diagnostics)")
    }
  }

  func testComposeIncludesSystemAndSections() throws {
    let p = Persona(
      id: "t",
      name: "Test",
      system: "SYSTEM",
      template: PromptTemplate(format: nil, sections: [
        TemplateSection(key: "goal", label: "Goal", required: true)
      ])
    )

    let out = PromptComposer.compose(persona: p, sections: ["goal": "Ship v1"])
    XCTAssertTrue(out.contains("SYSTEM"))
    XCTAssertTrue(out.contains("GOAL"))
    XCTAssertTrue(out.contains("Ship v1"))
  }

  func testExtendsIsRejected() throws {
    let json = """
    {
      "schemaVersion": 1,
      "documentType": "persona",
      "persona": {
        "id": "child",
        "name": "Child",
        "system": "SYSTEM",
        "extends": "parent",
        "systemAppend": "APPEND"
      }
    }
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("extends.persona.json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    switch result {
    case .success:
      XCTFail("Expected extends to be rejected")
    case .failure(let error):
      XCTAssertTrue(error.diagnostics.contains { $0.severity == .error && $0.message.contains("extends") })
      XCTAssertTrue(error.diagnostics.contains { $0.severity == .error && $0.message.contains("systemAppend") })
    }
  }

  func testDeterministicComposeForExamplePackPersonas() throws {
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
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
        "task": "Review the output"
      ],
      "media-export-correctness": [
        "context": "Export pipeline v2",
        "evidence": "Timing drift in 120fps",
        "task": "Find deterministic pitfalls"
      ]
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
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let personaURL = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")

    let packSet = try PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get()
    let personaSet = try PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get()

    let packMap = Dictionary(uniqueKeysWithValues: packSet.personas.map { ($0.id, $0) })
    let resolvedPack = PersonaResolver.resolveAll(from: packMap).personasByID

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let personas: [Persona] = [
      resolvedPack["senior-ios-engineer"]?.persona,
      personaSet.personas.first
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
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
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
      "task": "Compare outputs"
    ]

    let coreOutput = PromptComposer.compose(persona: persona, sections: sections)
    let cliOutput = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
    XCTAssertEqual(coreOutput, cliOutput)
  }

  func testCLIResolvedJSONMatchesCoreEncoding() throws {
    let personaURL = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")
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

  func testValidatorErrorsIncludeFixHints() throws {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/bad-pack.json"))
    let pack = PackMeta(id: "", name: "", author: nil, description: nil, homepage: nil)
    let persona = Persona(id: "", name: "", system: "")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])

    let diags = PersonaValidator.validate(set: set)
    XCTAssertFalse(diags.isEmpty)
    for d in diags {
      XCTAssertTrue(d.message.contains("Fix:"), "Missing fix hint in: \(d.message)")
      XCTAssertTrue(d.userFacingMessage.contains("Source:"), "Missing source label in: \(d.userFacingMessage)")
    }
  }

  func testDecodeErrorIncludesFixHint() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bad-persona.json")
    try "{ invalid json".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let result = PersonaLoader.loadDocument(from: tmp, sourceKind: .project)
    switch result {
    case .success:
      XCTFail("Expected decode failure")
    case .failure(let error):
      XCTAssertTrue(error.diagnostics.contains { $0.message.contains("Failed to decode JSON") })
    }
  }

  func testMetadataParsingAndSortedTags() throws {
    let json = """
    {
      "schemaVersion": 1,
      "documentType": "persona",
      "persona": {
        "id": "meta",
        "name": "Meta",
        "system": "SYSTEM",
        "tags": ["beta", "Alpha", "alpha"],
        "description": "Short about text."
      }
    }
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("meta.persona.json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    let set = try result.get()
    guard let persona = set.personas.first else {
      XCTFail("Missing persona")
      return
    }

    XCTAssertEqual(persona.description, "Short about text.")
    XCTAssertEqual(persona.about, "Short about text.")
    XCTAssertEqual(persona.sortedTags, ["Alpha", "alpha", "beta"])
    XCTAssertEqual(PersonaMetadata.sortedUniqueTags(from: [persona]), ["Alpha", "alpha", "beta"])
  }

  func testMetadataDoesNotAffectComposition() throws {
    let template = PromptTemplate(format: nil, sections: [
      TemplateSection(key: "context", label: "Context", required: true),
      TemplateSection(key: "task", label: "Task", required: true)
    ])

    let base = Persona(
      id: "meta-free",
      name: "Meta Free",
      system: "SYSTEM",
      template: template
    )

    let withMeta = Persona(
      id: "meta-free",
      name: "Meta Free",
      tags: ["alpha", "beta"],
      description: "About text.",
      system: "SYSTEM",
      template: template
    )

    let sections = [
      "context": "Repo: PersonaPad",
      "task": "Confirm output"
    ]

    let baseOutput = PromptComposer.compose(persona: base, sections: sections)
    let metaOutput = PromptComposer.compose(persona: withMeta, sections: sections)
    XCTAssertEqual(baseOutput, metaOutput)
  }
}
