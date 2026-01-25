import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Decoding")
struct PersonaPadCoreDecodingTests {
  @Test("Decode pack example")
  func decodePackExample() throws {
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    let set = try #require(try? result.get())
    #expect(set.pack.id == "com.afterimage.devpack")
    #expect(set.personas.count == 2)
  }

  @Test("Decode persona example")
  func decodePersonaExample() throws {
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.persona.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    let set = try #require(try? result.get())
    #expect(set.personas.count == 1)
    #expect(set.personas.first?.id == "debug-triage")
  }

  @Test("Extends is rejected")
  func extendsIsRejected() throws {
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
      #expect(Bool(false), "Expected extends to be rejected")
    case .failure(let error):
      #expect(
        error.diagnostics.contains { $0.severity == .error && $0.message.contains("extends") }
      )
      #expect(
        error.diagnostics.contains { $0.severity == .error && $0.message.contains("systemAppend") }
      )
    }
  }

  @Test("Validator errors include fix hints")
  func validatorErrorsIncludeFixHints() {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/bad-pack.json"))
    let pack = PackMeta(id: "", name: "", author: nil, description: nil, homepage: nil)
    let persona = Persona(id: "", name: "", system: "")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])

    let diags = PersonaValidator.validate(set: set)
    #expect(!diags.isEmpty)
    for diagnostic in diags {
      #expect(diagnostic.message.contains("Fix:"))
      #expect(diagnostic.userFacingMessage.contains("Source:"))
    }
  }

  @Test("Decode error includes fix hint")
  func decodeErrorIncludesFixHint() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bad-persona.json")
    try "{ invalid json".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let result = PersonaLoader.loadDocument(from: tmp, sourceKind: .project)
    switch result {
    case .success:
      #expect(Bool(false), "Expected decode failure")
    case .failure(let error):
      #expect(error.diagnostics.contains { $0.message.contains("Failed to decode JSON") })
    }
  }
}
