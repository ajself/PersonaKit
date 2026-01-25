import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreDecodingTests: XCTestCase {
  func testDecodePackExample() throws {
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.pack.json")
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
    let url = coreTestsRepoRootURL().appendingPathComponent("Examples/personapad.persona.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    switch result {
    case .success(let set):
      XCTAssertEqual(set.personas.count, 1)
      XCTAssertEqual(set.personas.first?.id, "debug-triage")
    case .failure(let error):
      XCTFail("Failed to decode persona example: \(error.diagnostics)")
    }
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
      XCTAssertTrue(
        error.diagnostics.contains { $0.severity == .error && $0.message.contains("extends") })
      XCTAssertTrue(
        error.diagnostics.contains { $0.severity == .error && $0.message.contains("systemAppend") })
    }
  }

  func testValidatorErrorsIncludeFixHints() throws {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/bad-pack.json"))
    let pack = PackMeta(id: "", name: "", author: nil, description: nil, homepage: nil)
    let persona = Persona(id: "", name: "", system: "")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])

    let diags = PersonaValidator.validate(set: set)
    XCTAssertFalse(diags.isEmpty)
    for diagnostic in diags {
      XCTAssertTrue(
        diagnostic.message.contains("Fix:"),
        "Missing fix hint in: \(diagnostic.message)"
      )
      XCTAssertTrue(
        diagnostic.userFacingMessage.contains("Source:"),
        "Missing source label in: \(diagnostic.userFacingMessage)"
      )
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
}
