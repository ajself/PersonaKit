import Testing

@testable import ContextMCP

struct MCPResourceMappingTests {
  @Test
  func packURIBuildsAndParses() throws {
    let reference = MCPResourceReference.pack(
      type: .personas,
      id: "senior-swiftui-engineer"
    )

    #expect(reference.uri == "personakit://packs/personas/senior-swiftui-engineer")

    let parsed = try MCPResourceReference.parse(uri: reference.uri)
    #expect(parsed == reference)
    #expect(parsed.relativePath == "Packs/personas/senior-swiftui-engineer.persona.json")
    #expect(parsed.mimeType == "application/json")
  }

  @Test
  func singularPackTypeErrorNamesValidTokens() throws {
    // A wrong (singular) type token must self-correct by naming the four valid plural
    // tokens, not read as a stale or deleted resource.
    #expect(throws: MCPResourceURIError.unknownPacksType("persona")) {
      try MCPResourceReference.parse(uri: "personakit://packs/persona/senior-swiftui-engineer")
    }

    let message = MCPResourceURIError.unknownPacksType("persona").errorDescription
    let description = try #require(message)
    #expect(description.contains("personas"))
    #expect(description.contains("kits"))
    #expect(description.contains("directives"))
    #expect(description.contains("skills"))
    #expect(description.contains("personakit://packs/kits/<id>"))
  }

  @Test
  func catalogURIBuildsAndParses() throws {
    let reference = MCPResourceReference.catalog(type: .index)

    #expect(reference.uri == "personakit://catalog/index")

    let parsed = try MCPResourceReference.parse(uri: reference.uri)
    #expect(parsed == reference)
    #expect(parsed.relativePath == "catalog/index")
    #expect(parsed.mimeType == "application/json")
  }

  @Test
  func resourceEntriesSortByURI() {
    let entries = [
      MCPResourceEntry(
        uri: "personakit://packs/kits/beta",
        name: "beta",
        mimeType: "application/json"
      ),
      MCPResourceEntry(
        uri: "personakit://catalog/index",
        name: "index",
        mimeType: "application/json"
      ),
      MCPResourceEntry(
        uri: "personakit://packs/kits/alpha",
        name: "alpha",
        mimeType: "application/json"
      ),
    ]

    let sorted = MCPResourceEntry.sorted(entries)

    #expect(
      sorted.map(\.uri) == [
        "personakit://catalog/index",
        "personakit://packs/kits/alpha",
        "personakit://packs/kits/beta",
      ]
    )
  }
}
