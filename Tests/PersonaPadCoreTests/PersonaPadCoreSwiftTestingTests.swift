#if canImport(Testing)
  import Testing
  @testable import PersonaPadCore
  import Foundation

  @Suite("PersonaPadCore Swift Testing")
  struct PersonaPadCoreSwiftTestingTests {
    private static func repoRootURL() -> URL {
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    }

    @Test("Decode pack example")
    func decodePackExample() throws {
      let url = Self.repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      let set = try #require(try? result.get())
      #expect(set.pack.id == "com.afterimage.devpack")
      #expect(set.personas.count == 2)
    }

    @Test("Decode persona example")
    func decodePersonaExample() throws {
      let url = Self.repoRootURL().appendingPathComponent("Examples/personapad.persona.json")
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      let set = try #require(try? result.get())
      #expect(set.personas.count == 1)
      #expect(set.personas.first?.id == "debug-triage")
    }

    // Extends is intentionally unsupported in v1; XCTest covers the rejection path.
  }
#endif
