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
