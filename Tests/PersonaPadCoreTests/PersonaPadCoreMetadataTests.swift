import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Metadata")
struct PersonaPadCoreMetadataTests {
  @Test("Metadata parsing and sorted tags")
  func metadataParsingAndSortedTags() throws {
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
    let set = try #require(try? result.get())
    let persona = try #require(set.personas.first)

    #expect(persona.description == "Short about text.")
    #expect(persona.about == "Short about text.")
    #expect(persona.sortedTags == ["Alpha", "alpha", "beta"])
    #expect(PersonaMetadata.sortedUniqueTags(from: [persona]) == ["Alpha", "alpha", "beta"])
  }

  @Test("Persona sort key orders by name then id")
  func personaSortKeyOrdersByNameThenId() {
    let personaA1 = Persona(id: "alpha-2", name: "Alpha", system: "SYSTEM")
    let personaA0 = Persona(id: "alpha-1", name: "Alpha", system: "SYSTEM")
    let personaB = Persona(id: "beta-1", name: "beta", system: "SYSTEM")

    let sorted = [personaB, personaA1, personaA0].sorted {
      PersonaMetadata.personaSortKey($0) < PersonaMetadata.personaSortKey($1)
    }

    #expect(sorted.map(\.id) == ["alpha-1", "alpha-2", "beta-1"])
  }

  @Test("Metadata does not affect composition")
  func metadataDoesNotAffectComposition() {
    var templateSections: [TemplateSection] = []
    templateSections.append(TemplateSection(key: "context", label: "Context", required: true))
    templateSections.append(TemplateSection(key: "task", label: "Task", required: true))
    let template = PromptTemplate(format: nil, sections: templateSections)

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

    let sections = ["context": "Repo: PersonaPad", "task": "Confirm output"]

    let baseOutput = PromptComposer.compose(persona: base, sections: sections)
    let metaOutput = PromptComposer.compose(persona: withMeta, sections: sections)
    #expect(baseOutput == metaOutput)
  }
}
