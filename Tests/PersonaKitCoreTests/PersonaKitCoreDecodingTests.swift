import Foundation
import Testing

@testable import PersonaKitCore

@Suite("PersonaKitCore Decoding")
struct PersonaKitCoreDecodingTests {
  private func withTemporaryJSONFile(
    named name: String,
    contents: String,
    _ operation: (URL) throws -> Void
  ) throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    try operation(url)
  }

  @Test("Decode pack example")
  func decodePackExample() throws {
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personakit.pack.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    let set = try #require(try? result.get())
    #expect(set.pack.id == "com.afterimage.devpack")
    #expect(set.personas.count == 2)
  }

  @Test("Decode persona example")
  func decodePersonaExample() throws {
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personakit.persona.json")
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

  @Test("Document envelope rejects missing or unsupported documentType")
  func documentEnvelopeRejectsMissingOrUnsupportedDocumentType() throws {
    try withTemporaryJSONFile(
      named: "missing-document-type.json",
      contents: """
        {
          "schemaVersion": 1,
          "persona": {
            "id": "p1",
            "name": "Persona",
            "system": "SYSTEM"
          }
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected missing documentType to fail")
      case .failure(let error):
        #expect(error.diagnostics.contains { $0.message.contains("Missing documentType") })
      }
    }

    try withTemporaryJSONFile(
      named: "unsupported-document-type.json",
      contents: """
        {
          "schemaVersion": 1,
          "documentType": "unsupported",
          "persona": {
            "id": "p1",
            "name": "Persona",
            "system": "SYSTEM"
          }
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected unsupported documentType to fail")
      case .failure(let error):
        #expect(error.diagnostics.contains { $0.message.contains("Unsupported documentType") })
      }
    }
  }

  @Test("Document envelope rejects unsupported schemaVersion")
  func documentEnvelopeRejectsUnsupportedSchemaVersion() throws {
    try withTemporaryJSONFile(
      named: "unsupported-schema-version.json",
      contents: """
        {
          "schemaVersion": 2,
          "documentType": "persona",
          "persona": {
            "id": "p1",
            "name": "Persona",
            "system": "SYSTEM"
          }
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected unsupported schemaVersion to fail")
      case .failure(let error):
        #expect(error.diagnostics.contains { $0.message.contains("Unsupported schemaVersion: 2") })
      }
    }
  }

  @Test("Document envelope validates personaPack requirements")
  func documentEnvelopeValidatesPersonaPackRequirements() throws {
    try withTemporaryJSONFile(
      named: "missing-pack-personas.json",
      contents: """
        {
          "schemaVersion": 1,
          "documentType": "personaPack"
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected missing pack/personas to fail")
      case .failure(let error):
        #expect(
          error.diagnostics.contains {
            $0.message.contains("personaPack requires 'pack' and non-empty 'personas'")
          }
        )
      }
    }
  }

  @Test("Document envelope reports invalid defaults and personas payloads")
  func documentEnvelopeReportsInvalidDefaultsAndPersonasPayloads() throws {
    try withTemporaryJSONFile(
      named: "invalid-defaults.json",
      contents: """
        {
          "schemaVersion": 1,
          "documentType": "personaPack",
          "pack": { "id": "pack.id", "name": "Pack" },
          "defaults": "nope",
          "personas": [
            { "id": "p1", "name": "Persona", "system": "SYSTEM" }
          ]
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected invalid defaults to fail")
      case .failure(let error):
        #expect(error.diagnostics.contains { $0.message.contains("Invalid 'defaults' object") })
      }
    }

    try withTemporaryJSONFile(
      named: "invalid-personas.json",
      contents: """
        {
          "schemaVersion": 1,
          "documentType": "personaPack",
          "pack": { "id": "pack.id", "name": "Pack" },
          "personas": { "id": "p1" }
        }
        """
    ) { url in
      let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
      switch result {
      case .success:
        #expect(Bool(false), "Expected invalid personas payload to fail")
      case .failure(let error):
        #expect(error.diagnostics.contains { $0.message.contains("Invalid 'personas' array") })
        #expect(
          error.diagnostics.contains {
            $0.message.contains("personaPack requires 'pack' and non-empty 'personas'")
          }
        )
      }
    }
  }

  @Test("Validator flags empty pack and persona fields")
  func validatorFlagsEmptyPackAndPersonaFields() {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/bad-pack.json"))
    let pack = PackMeta(id: " ", name: "\n", author: nil, description: nil, homepage: nil)
    let persona = Persona(id: " ", name: " ", system: "\t")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])

    let diags = PersonaValidator.validate(set: set)
    #expect(diags.contains { $0.message.contains("Pack 'id' must be non-empty") })
    #expect(diags.contains { $0.message.contains("Pack 'name' must be non-empty") })
    #expect(diags.contains { $0.message.contains("Persona 'id' must be non-empty") })
    #expect(diags.contains { $0.message.contains("has empty 'name'") })
    #expect(diags.contains { $0.message.contains("has empty 'system'") })
  }

  @Test("Validator reports duplicate persona ids")
  func validatorReportsDuplicatePersonaIDs() {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/dupe.json"))
    let pack = PackMeta(id: "pack.id", name: "Pack", author: nil, description: nil, homepage: nil)
    let personaA = Persona(id: "dup", name: "A", system: "SYSTEM")
    let personaB = Persona(id: "dup", name: "B", system: "SYSTEM")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [personaA, personaB])

    let diags = PersonaValidator.validate(set: set)
    #expect(diags.contains { $0.message.contains("Duplicate persona id in pack: 'dup'") })
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
