import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Describe")
struct PersonaPadCoreDescribeTests {
  @Test("Describe includes description and tags")
  func describeIncludesDescriptionAndTags() {
    let persona = Persona(
      id: "meta",
      name: "Meta",
      tags: ["beta", "Alpha", "alpha", "beta"],
      description: "About text.",
      system: "SYSTEM"
    )
    let resolved = [persona.id: ResolvedPersona(baseIDs: [persona.id], persona: persona)]
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/meta.persona.json"))
    let pack = PackMeta(id: "pack.id", name: "Pack", author: nil, description: nil, homepage: nil)

    let result = PersonaDescriptor.describe(
      personaID: persona.id,
      resolved: resolved,
      sourcesByID: [persona.id: source],
      packsByID: [persona.id: pack],
      baseURL: nil
    )

    switch result {
    case .failure(let failure):
      #expect(Bool(false), "Unexpected failure: \(failure)")
    case .success(let text):
      let lines = text.split(separator: "\n").map(String.init)
      #expect(lines.first == "Name: Meta")
      #expect(lines.contains("Description: About text."))
      #expect(lines.contains("Tags: Alpha, alpha, beta"))
      #expect(lines.contains("Source: /tmp/meta.persona.json"))
    }
  }

  @Test("Describe tags are sorted and unique")
  func describeTagsAreSortedAndUnique() {
    let tags = ["beta", "Alpha", "alpha", "beta"]
    let sorted = PersonaDescriptor.sortedUniqueTags(from: tags)
    #expect(sorted == ["Alpha", "alpha", "beta"])
  }

  @Test("Describe unknown persona returns failure")
  func describeUnknownPersonaReturnsFailure() {
    let result = PersonaDescriptor.describe(
      personaID: "missing",
      resolved: [:],
      sourcesByID: [:],
      packsByID: [:]
    )

    switch result {
    case .success:
      #expect(Bool(false), "Expected failure for missing persona")
    case .failure(let failure):
      #expect(failure.exitCode == 2)
      #expect(failure.message.contains("Persona not found"))
      #expect(failure.message.contains("personapad list"))
    }
  }
}
