import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreDescribeTests: XCTestCase {
  func testDescribeIncludesDescriptionAndTags() throws {
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
      XCTFail("Unexpected failure: \(failure)")
    case .success(let text):
      let lines = text.split(separator: "\n").map(String.init)
      XCTAssertEqual(lines.first, "Name: Meta")
      XCTAssertTrue(lines.contains("Description: About text."))
      XCTAssertTrue(lines.contains("Tags: Alpha, alpha, beta"))
      XCTAssertTrue(lines.contains("Source: /tmp/meta.persona.json"))
    }
  }

  func testDescribeTagsAreSortedAndUnique() throws {
    let tags = ["beta", "Alpha", "alpha", "beta"]
    let sorted = PersonaDescriptor.sortedUniqueTags(from: tags)
    XCTAssertEqual(sorted, ["Alpha", "alpha", "beta"])
  }

  func testDescribeUnknownPersonaReturnsFailure() throws {
    let result = PersonaDescriptor.describe(
      personaID: "missing",
      resolved: [:],
      sourcesByID: [:],
      packsByID: [:]
    )

    switch result {
    case .success:
      XCTFail("Expected failure for missing persona")
    case .failure(let failure):
      XCTAssertEqual(failure.exitCode, 2)
      XCTAssertTrue(failure.message.contains("Persona not found"))
      XCTAssertTrue(failure.message.contains("personapad list"))
    }
  }
}
