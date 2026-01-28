import Dependencies
import Foundation
import Testing

@testable import PersonaKitCore

@Suite("PersonaKitCore Import")
struct PersonaKitCoreImportTests {
  @Test("Import plan from pack file includes companions")
  func importPlanFromPackFileIncludesCompanions() throws {
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

    let plan = try #require(try? PersonaPackImportPlan.plan(from: packURL).get())
    #expect(plan.sourceRoot.standardizedFileURL == root.standardizedFileURL)
    #expect(plan.pack.id == "pack.id")

    let filenames = plan.filesToCopy.map(\.lastPathComponent)
    #expect(filenames.contains("Example.pack.json"))
    #expect(filenames.contains("Extra.persona.json"))
    #expect(filenames.contains("Extra.meta.json"))
    #expect(filenames.contains("Nested.persona.json"))

    let nestedRelative = plan.relativePath(for: nestedPersonaURL)
    #expect(nestedRelative == "Sub/Nested.persona.json")
  }

  @Test("Import plan uses dependency file client when none provided")
  func importPlanUsesDependencyFileClientWhenNoneProvided() throws {
    let packURL = URL(fileURLWithPath: "/tmp/Example.pack.json")
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

    var fileClient = FileClient.liveValue
    fileClient.isDirectory = { _ in false }
    fileClient.contentsOfDirectory = { _, _ in [] }
    fileClient.enumerator = { _, _, _ in nil }
    fileClient.readData = { _ in
      return Data(packJSON.utf8)
    }

    let result = withDependencies {
      $0.fileClient = fileClient
    } operation: {
      PersonaPackImportPlan.plan(from: packURL)
    }

    let plan = try #require(try? result.get())
    #expect(plan.pack.id == "pack.id")
  }

  @Test("Import plan allows same filename in different folders")
  func importPlanAllowsSameFilenameInDifferentFolders() throws {
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

    let plan = try #require(try? PersonaPackImportPlan.plan(from: packURL).get())
    let relativeA = plan.relativePath(for: fileA)
    let relativeB = plan.relativePath(for: fileB)
    #expect(relativeA == "A/Extra.persona.json")
    #expect(relativeB == "B/Extra.persona.json")
    #expect(relativeA != relativeB)
  }

  @Test("Import plan rejects multiple pack files in folder")
  func importPlanRejectsMultiplePackFilesInFolder() throws {
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
      #expect(Bool(false), "Expected multiple pack files to be rejected")
    case .failure(let error):
      switch error {
      case .multiplePackFiles(let directory, let files):
        #expect(directory.standardizedFileURL == root.standardizedFileURL)
        #expect(files.map(\.lastPathComponent).sorted() == ["A.pack.json", "B.pack.json"])
      default:
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }
  }

  @Test("Import plan rejects unsupported selection")
  func importPlanRejectsUnsupportedSelection() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let fileURL = root.appendingPathComponent("Notes.json")
    try "{ \"schemaVersion\": 1 }".write(to: fileURL, atomically: true, encoding: .utf8)

    let result = PersonaPackImportPlan.plan(from: fileURL)
    switch result {
    case .success:
      #expect(Bool(false), "Expected unsupported selection to be rejected")
    case .failure(let error):
      switch error {
      case .unsupportedSelection(let url):
        #expect(url.standardizedFileURL == fileURL.standardizedFileURL)
      default:
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }
  }

  @Test("Import plan rejects invalid JSON pack file")
  func importPlanRejectsInvalidJSONPackFile() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packURL = root.appendingPathComponent("Bad.pack.json")
    try "{ not json".write(to: packURL, atomically: true, encoding: .utf8)

    let result = PersonaPackImportPlan.plan(from: packURL)
    switch result {
    case .success:
      #expect(Bool(false), "Expected invalid JSON pack file to fail")
    case .failure(let error):
      switch error {
      case .invalidPackFile(let url, let message):
        #expect(url.standardizedFileURL == packURL.standardizedFileURL)
        #expect(message.contains("valid JSON"))
      default:
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }
  }

  @Test("Import plan rejects non-pack documentType")
  func importPlanRejectsNonPackDocumentType() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let packURL = root.appendingPathComponent("Wrong.pack.json")
    let json = """
      {
        "schemaVersion": 1,
        "documentType": "persona",
        "persona": { "id": "p1", "name": "P1", "system": "SYSTEM" }
      }
      """
    try json.write(to: packURL, atomically: true, encoding: .utf8)

    let result = PersonaPackImportPlan.plan(from: packURL)
    switch result {
    case .success:
      #expect(Bool(false), "Expected wrong documentType to fail")
    case .failure(let error):
      switch error {
      case .invalidPackFile(let url, let message):
        #expect(url.standardizedFileURL == packURL.standardizedFileURL)
        #expect(message.contains("documentType must be 'personaPack'"))
      default:
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }
  }

  @Test("Import plan rejects companion files outside source root")
  func importPlanRejectsCompanionFilesOutsideSourceRoot() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let outsideRoot = fm.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    try fm.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    defer { try? fm.removeItem(at: outsideRoot) }

    let packURL = root.appendingPathComponent("Example.pack.json")
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
    try packJSON.write(to: packURL, atomically: true, encoding: .utf8)

    let outsidePersona = outsideRoot.appendingPathComponent("Outside.persona.json")
    let personaJSON = """
      {
        "schemaVersion": 1,
        "documentType": "persona",
        "persona": { "id": "p2", "name": "P2", "system": "SYSTEM" }
      }
      """
    try personaJSON.write(to: outsidePersona, atomically: true, encoding: .utf8)

    let symlinkURL = root.appendingPathComponent("Outside.persona.json")
    try fm.createSymbolicLink(at: symlinkURL, withDestinationURL: outsidePersona)

    let result = PersonaPackImportPlan.plan(from: packURL)
    switch result {
    case .success:
      #expect(Bool(false), "Expected outside companion file to be rejected")
    case .failure(let error):
      switch error {
      case .fileOutsideSourceRoot(let url):
        #expect(url.lastPathComponent == "Outside.persona.json")
      default:
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }
  }

  @Test("User pack loader combines folder personas")
  func userPackLoaderCombinesFolderPersonas() throws {
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
    #expect(loaded.packs.count == 1)
    #expect(loaded.packs.first?.set.personas.count == 2)
    #expect(loaded.packs.first?.packRoot.standardizedFileURL == packFolder.standardizedFileURL)
  }

  @Test("User pack loader uses dependency file client when none provided")
  func userPackLoaderUsesDependencyFileClientWhenNoneProvided() throws {
    let root = URL(fileURLWithPath: "/tmp/user-packs")
    let packURL = root.appendingPathComponent("Pack.pack.json")
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

    var fileClient = FileClient.liveValue
    fileClient.contentsOfDirectory = { url, _ in
      guard url.standardizedFileURL == root.standardizedFileURL else { return [] }
      return [packURL]
    }
    fileClient.isDirectory = { _ in false }
    fileClient.readData = { url in
      guard url.standardizedFileURL == packURL.standardizedFileURL else {
        struct UnexpectedRead: Error {}
        throw UnexpectedRead()
      }
      return Data(packJSON.utf8)
    }

    let loaded = withDependencies {
      $0.fileClient = fileClient
    } operation: {
      UserPackLoader.load(in: root)
    }

    #expect(loaded.packs.count == 1)
    #expect(loaded.packs.first?.set.pack.id == "pack.id")
  }
}
