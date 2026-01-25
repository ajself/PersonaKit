import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreMetadataTests: XCTestCase {
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

  func testPersonaSortKeyOrdersByNameThenId() throws {
    let personaA1 = Persona(id: "alpha-2", name: "Alpha", system: "SYSTEM")
    let personaA0 = Persona(id: "alpha-1", name: "Alpha", system: "SYSTEM")
    let personaB = Persona(id: "beta-1", name: "beta", system: "SYSTEM")

    let sorted = [personaB, personaA1, personaA0].sorted {
      PersonaMetadata.personaSortKey($0) < PersonaMetadata.personaSortKey($1)
    }

    XCTAssertEqual(sorted.map(\.id), ["alpha-1", "alpha-2", "beta-1"])
  }

  func testMetadataDoesNotAffectComposition() throws {
    let template = PromptTemplate(
      format: nil,
      sections: [
        TemplateSection(key: "context", label: "Context", required: true),
        TemplateSection(key: "task", label: "Task", required: true),
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
      "task": "Confirm output",
    ]

    let baseOutput = PromptComposer.compose(persona: base, sections: sections)
    let metaOutput = PromptComposer.compose(persona: withMeta, sections: sections)
    XCTAssertEqual(baseOutput, metaOutput)
  }
}
