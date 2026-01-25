import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreImportTests: XCTestCase {
  func testImportPlanFromPackFileIncludesCompanions() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packURL = root.appendingPathComponent("Example.pack.json")
    let personaURL = root.appendingPathComponent("Extra.persona.json")
    let metaURL = root.appendingPathComponent("Extra.meta.json")
    let nestedFolder = root.appendingPathComponent("Sub", isDirectory: true)
    try fm.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
    let nestedPersonaURL = nestedFolder.appendingPathComponent("Nested.persona.json")

    let packJSON = """
      {
        "schemaVersion": 1,
        "documentType": "personaPack",
        "pack": { "id": "pack.id", "name": "Pack" },
        "personas": [
          { "id": "p1", "name": "P1", "system": "SYSTEM" }
        ]
      }
      """
    let personaJSON = """
      {
        "schemaVersion": 1,
        "documentType": "persona",
        "persona": { "id": "p2", "name": "P2", "system": "SYSTEM" }
      }
      """
    try packJSON.write(to: packURL, atomically: true, encoding: .utf8)
    try personaJSON.write(to: personaURL, atomically: true, encoding: .utf8)
    try "{}".write(to: metaURL, atomically: true, encoding: .utf8)
    try personaJSON.write(to: nestedPersonaURL, atomically: true, encoding: .utf8)

    let plan = try PersonaPackImportPlan.plan(from: packURL).get()
    XCTAssertEqual(plan.sourceRoot.standardizedFileURL, root.standardizedFileURL)
    XCTAssertEqual(plan.pack.id, "pack.id")

    let filenames = plan.filesToCopy.map(\.lastPathComponent)
    XCTAssertTrue(filenames.contains("Example.pack.json"))
    XCTAssertTrue(filenames.contains("Extra.persona.json"))
    XCTAssertTrue(filenames.contains("Extra.meta.json"))
    XCTAssertTrue(filenames.contains("Nested.persona.json"))

    let nestedRelative = plan.relativePath(for: nestedPersonaURL)
    XCTAssertEqual(nestedRelative, "Sub/Nested.persona.json")
  }

  func testImportPlanAllowsSameFilenameInDifferentFolders() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packURL = root.appendingPathComponent("Example.pack.json")
    let subA = root.appendingPathComponent("A", isDirectory: true)
    let subB = root.appendingPathComponent("B", isDirectory: true)
    try fm.createDirectory(at: subA, withIntermediateDirectories: true)
    try fm.createDirectory(at: subB, withIntermediateDirectories: true)
    let fileA = subA.appendingPathComponent("Extra.persona.json")
    let fileB = subB.appendingPathComponent("Extra.persona.json")

    let packJSON = """
      {
        "schemaVersion": 1,
        "documentType": "personaPack",
        "pack": { "id": "pack.id", "name": "Pack" },
        "personas": [
          { "id": "p1", "name": "P1", "system": "SYSTEM" }
        ]
      }
      """
    let personaJSON = """
      {
        "schemaVersion": 1,
        "documentType": "persona",
        "persona": { "id": "p2", "name": "P2", "system": "SYSTEM" }
      }
      """
    try packJSON.write(to: packURL, atomically: true, encoding: .utf8)
    try personaJSON.write(to: fileA, atomically: true, encoding: .utf8)
    try personaJSON.write(to: fileB, atomically: true, encoding: .utf8)

    let plan = try PersonaPackImportPlan.plan(from: packURL).get()
    let relativeA = plan.relativePath(for: fileA)
    let relativeB = plan.relativePath(for: fileB)
    XCTAssertEqual(relativeA, "A/Extra.persona.json")
    XCTAssertEqual(relativeB, "B/Extra.persona.json")
    XCTAssertNotEqual(relativeA, relativeB)
  }

  func testImportPlanRejectsMultiplePackFilesInFolder() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packA = root.appendingPathComponent("A.pack.json")
    let packB = root.appendingPathComponent("B.pack.json")

    let packJSON = """
      {
        "schemaVersion": 1,
        "documentType": "personaPack",
        "pack": { "id": "pack.id", "name": "Pack" },
        "personas": [
          { "id": "p1", "name": "P1", "system": "SYSTEM" }
        ]
      }
      """
    try packJSON.write(to: packA, atomically: true, encoding: .utf8)
    try packJSON.write(to: packB, atomically: true, encoding: .utf8)

    let result = PersonaPackImportPlan.plan(from: root)
    switch result {
    case .success:
      XCTFail("Expected multiple pack files to be rejected")
    case .failure(let error):
      switch error {
      case .multiplePackFiles(let directory, let files):
        XCTAssertEqual(directory.standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(files.map(\.lastPathComponent).sorted(), ["A.pack.json", "B.pack.json"])
      default:
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testUserPackLoaderCombinesFolderPersonas() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let packFolder = root.appendingPathComponent("MyPack", isDirectory: true)
    try fm.createDirectory(at: packFolder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packURL = packFolder.appendingPathComponent("My.pack.json")
    let personaURL = packFolder.appendingPathComponent("Extra.persona.json")

    let packJSON = """
      {
        "schemaVersion": 1,
        "documentType": "personaPack",
        "pack": { "id": "pack.id", "name": "Pack" },
        "personas": [
          { "id": "p1", "name": "P1", "system": "SYSTEM" }
        ]
      }
      """
    let personaJSON = """
      {
        "schemaVersion": 1,
        "documentType": "persona",
        "persona": { "id": "p2", "name": "P2", "system": "SYSTEM" }
      }
      """
    try packJSON.write(to: packURL, atomically: true, encoding: .utf8)
    try personaJSON.write(to: personaURL, atomically: true, encoding: .utf8)

    let loaded = UserPackLoader.load(in: root)
    XCTAssertEqual(loaded.packs.count, 1)
    XCTAssertEqual(loaded.packs.first?.set.personas.count, 2)
    XCTAssertEqual(loaded.packs.first?.packRoot.standardizedFileURL, packFolder.standardizedFileURL)
  }
}
