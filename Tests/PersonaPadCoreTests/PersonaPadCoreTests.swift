import XCTest
@testable import PersonaPadCore

final class PersonaPadCoreTests: XCTestCase {
  private func repoRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  func testDecodePackExample() throws {
    let url = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
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
    let url = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")
    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    switch result {
    case .success(let set):
      XCTAssertEqual(set.personas.count, 1)
      XCTAssertEqual(set.personas.first?.id, "debug-triage")
    case .failure(let error):
      XCTFail("Failed to decode persona example: \(error.diagnostics)")
    }
  }

  func testComposeIncludesSystemAndSections() throws {
    let p = Persona(
      id: "t",
      name: "Test",
      system: "SYSTEM",
      template: PromptTemplate(format: nil, sections: [
        TemplateSection(key: "goal", label: "Goal", required: true)
      ])
    )

    let out = PromptComposer.compose(persona: p, sections: ["goal": "Ship v1"])
    XCTAssertTrue(out.contains("SYSTEM"))
    XCTAssertTrue(out.contains("GOAL"))
    XCTAssertTrue(out.contains("Ship v1"))
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
      XCTAssertTrue(error.diagnostics.contains { $0.severity == .error && $0.message.contains("extends") })
      XCTAssertTrue(error.diagnostics.contains { $0.severity == .error && $0.message.contains("systemAppend") })
    }
  }

  func testDeterministicComposeForExamplePackPersonas() throws {
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let result = PersonaLoader.loadDocument(from: packURL, sourceKind: .project)
    let set = try result.get()
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID

    let ids = ["senior-ios-engineer", "media-export-correctness"]
    let sectionsByID: [String: [String: String]] = [
      "senior-ios-engineer": [
        "context": "Repo: PersonaPad",
        "goal": "Verify deterministic prompt output",
        "constraints": "No behavior changes",
        "evidence": "Determinism tests",
        "task": "Review the output"
      ],
      "media-export-correctness": [
        "context": "Export pipeline v2",
        "evidence": "Timing drift in 120fps",
        "task": "Find deterministic pitfalls"
      ]
    ]

    for id in ids {
      guard let persona = resolved[id]?.persona else {
        XCTFail("Missing persona \(id)")
        continue
      }
      guard let sections = sectionsByID[id] else {
        XCTFail("Missing sections for \(id)")
        continue
      }
      let first = PromptComposer.compose(persona: persona, sections: sections)
      for _ in 0..<5 {
        let next = PromptComposer.compose(persona: persona, sections: sections)
        XCTAssertEqual(first, next)
      }
    }
  }

  func testResolvedJSONDeterministicEncoding() throws {
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let personaURL = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")

    let packSet = try PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get()
    let personaSet = try PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get()

    let packMap = Dictionary(uniqueKeysWithValues: packSet.personas.map { ($0.id, $0) })
    let resolvedPack = PersonaResolver.resolveAll(from: packMap).personasByID

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let personas: [Persona] = [
      resolvedPack["senior-ios-engineer"]?.persona,
      personaSet.personas.first
    ].compactMap { $0 }

    XCTAssertEqual(personas.count, 2)

    for persona in personas {
      let firstData = try encoder.encode(persona)
      let firstText = String(data: firstData, encoding: .utf8)
      for _ in 0..<5 {
        let nextData = try encoder.encode(persona)
        let nextText = String(data: nextData, encoding: .utf8)
        XCTAssertEqual(firstText, nextText)
      }
    }
  }

  func testCLIOutputMatchesCorePrompt() throws {
    let packURL = repoRootURL().appendingPathComponent("Examples/personapad.pack.json")
    let set = try PersonaLoader.loadDocument(from: packURL, sourceKind: .project).get()
    let personaMap = Dictionary(uniqueKeysWithValues: set.personas.map { ($0.id, $0) })
    let resolved = PersonaResolver.resolveAll(from: personaMap).personasByID
    guard let persona = resolved["senior-ios-engineer"]?.persona else {
      XCTFail("Missing persona")
      return
    }

    let sections = [
      "context": "Repo: PersonaPad",
      "goal": "Prove CLI parity",
      "constraints": "No divergence",
      "evidence": "Unit test",
      "task": "Compare outputs"
    ]

    let coreOutput = PromptComposer.compose(persona: persona, sections: sections)
    let cliOutput = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
    XCTAssertEqual(coreOutput, cliOutput)
  }

  func testCLIResolvedJSONMatchesCoreEncoding() throws {
    let personaURL = repoRootURL().appendingPathComponent("Examples/personapad.persona.json")
    let set = try PersonaLoader.loadDocument(from: personaURL, sourceKind: .project).get()
    guard let persona = set.personas.first else {
      XCTFail("Missing persona")
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let coreText = String(data: try encoder.encode(persona), encoding: .utf8)
    let cliText = PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true)
    XCTAssertEqual(coreText, cliText)
  }

  func testValidatorErrorsIncludeFixHints() throws {
    let source = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/bad-pack.json"))
    let pack = PackMeta(id: "", name: "", author: nil, description: nil, homepage: nil)
    let persona = Persona(id: "", name: "", system: "")
    let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])

    let diags = PersonaValidator.validate(set: set)
    XCTAssertFalse(diags.isEmpty)
    for d in diags {
      XCTAssertTrue(d.message.contains("Fix:"), "Missing fix hint in: \(d.message)")
      XCTAssertTrue(d.userFacingMessage.contains("Source:"), "Missing source label in: \(d.userFacingMessage)")
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

  func testMetadataParsingAndSortedTags() throws {
    let json = """
    {
      "schemaVersion": 1,
      "documentType": "persona",
      "persona": {
        "id": "meta",
        "name": "Meta",
        "system": "SYSTEM",
        "tags": ["beta", "Alpha", "alpha"],
        "description": "Short about text."
      }
    }
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("meta.persona.json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = PersonaLoader.loadDocument(from: url, sourceKind: .project)
    let set = try result.get()
    guard let persona = set.personas.first else {
      XCTFail("Missing persona")
      return
    }

    XCTAssertEqual(persona.description, "Short about text.")
    XCTAssertEqual(persona.about, "Short about text.")
    XCTAssertEqual(persona.sortedTags, ["Alpha", "alpha", "beta"])
    XCTAssertEqual(PersonaMetadata.sortedUniqueTags(from: [persona]), ["Alpha", "alpha", "beta"])
  }

  func testPersonaSortKeyOrdersByNameThenId() throws {
    let personaA1 = Persona(id: "alpha-2", name: "Alpha", system: "SYSTEM")
    let personaA0 = Persona(id: "alpha-1", name: "Alpha", system: "SYSTEM")
    let personaB = Persona(id: "beta-1", name: "beta", system: "SYSTEM")

    let sorted = [personaB, personaA1, personaA0].sorted {
      PersonaMetadata.personaSortKey($0) < PersonaMetadata.personaSortKey($1)
    }

    XCTAssertEqual(sorted.map(\.id), ["alpha-1", "alpha-2", "beta-1"])
  }

  func testMetadataDoesNotAffectComposition() throws {
    let template = PromptTemplate(format: nil, sections: [
      TemplateSection(key: "context", label: "Context", required: true),
      TemplateSection(key: "task", label: "Task", required: true)
    ])

    let base = Persona(
      id: "meta-free",
      name: "Meta Free",
      system: "SYSTEM",
      template: template
    )

    let withMeta = Persona(
      id: "meta-free",
      name: "Meta Free",
      tags: ["alpha", "beta"],
      description: "About text.",
      system: "SYSTEM",
      template: template
    )

    let sections = [
      "context": "Repo: PersonaPad",
      "task": "Confirm output"
    ]

    let baseOutput = PromptComposer.compose(persona: base, sections: sections)
    let metaOutput = PromptComposer.compose(persona: withMeta, sections: sections)
    XCTAssertEqual(baseOutput, metaOutput)
  }

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

  func testPackDiffClassifiesAndSortsDeterministically() throws {
    let left: [PersonaDiffRecord] = [
      PersonaDiffRecord(key: "z", id: "zeta", name: "Zeta", contentHash: "a"),
      PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"),
      PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha", contentHash: "c")
    ]
    let right: [PersonaDiffRecord] = [
      PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"),
      PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha Updated", contentHash: "d"),
      PersonaDiffRecord(key: "c", id: "charlie", name: "Charlie", contentHash: "e")
    ]

    let diff = PackDiffBuilder.diff(left: Array(left.reversed()), right: Array(right.reversed()))

    XCTAssertEqual(diff.added.map(\.id), ["charlie"])
    XCTAssertEqual(diff.removed.map(\.id), ["zeta"])
    XCTAssertEqual(diff.modified.map(\.id), ["alpha"])

    let addedDiff = PackDiffBuilder.diff(left: [], right: [
      PersonaDiffRecord(key: "b", id: "b", name: "Beta", contentHash: "1"),
      PersonaDiffRecord(key: "a", id: "a", name: "Alpha", contentHash: "1")
    ])
    XCTAssertEqual(addedDiff.added.map(\.id), ["a", "b"])
  }

  func testStoragePathsAreDeterministic() throws {
    let home = URL(fileURLWithPath: "/Users/tester")
    let paths = PersonaPadStoragePaths.standard(homeDirectory: home)
    XCTAssertEqual(paths.root.path, "/Users/tester/Library/Application Support/PersonaPad")
    XCTAssertEqual(paths.packs.path, "/Users/tester/Library/Application Support/PersonaPad/Packs")
    XCTAssertEqual(paths.state.path, "/Users/tester/Library/Application Support/PersonaPad/State")
  }

  func testSavedFiltersRoundTripDeterministicEncoding() throws {
    let filters = [
      SavedFilter(
        id: "b",
        name: "Beta",
        queryText: "beta",
        selectedTags: ["tag-b"],
        selectedSources: ["user"],
        groupingMode: nil
      ),
      SavedFilter(
        id: "a",
        name: "Alpha",
        queryText: "alpha",
        selectedTags: ["tag-a"],
        selectedSources: ["builtIn"],
        groupingMode: "tag"
      )
    ]

    let data1 = try XCTUnwrap(SavedFiltersStore.encode(filters))
    let decoded = try XCTUnwrap(SavedFiltersStore.decode(data1))
    let data2 = try XCTUnwrap(SavedFiltersStore.encode(decoded))
    XCTAssertEqual(data1, data2)
  }

  func testSavedFiltersLoadSortsByNameThenId() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("filters.json")
    let store = SavedFiltersStore(fileURL: fileURL)

    let filters = [
      SavedFilter(
        id: "b2",
        name: "Beta",
        queryText: "beta",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      ),
      SavedFilter(
        id: "a2",
        name: "Alpha",
        queryText: "alpha-2",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      ),
      SavedFilter(
        id: "a1",
        name: "Alpha",
        queryText: "alpha-1",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      )
    ]

    store.save(filters)
    let loaded = store.load()
    XCTAssertEqual(loaded.map(\.id), ["a1", "a2", "b2"])
  }

  func testPinnedPersonasMissingFileReturnsEmpty() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("pins.json")
    let store = PinnedPersonasStore(fileURL: fileURL)

    XCTAssertEqual(store.load(), [])
  }

  func testPinnedPersonasSaveSortsDeterministically() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("pins.json")
    let store = PinnedPersonasStore(fileURL: fileURL)

    store.save(["zeta", "alpha", "beta"])
    let loaded = store.load()
    XCTAssertEqual(loaded, ["alpha", "beta", "zeta"])
  }

  func testPinnedPersonasRoundTripDeterministicEncoding() throws {
    let pins = ["beta", "alpha"]
    let data1 = try XCTUnwrap(PinnedPersonasStore.encode(pins))
    let decoded = try XCTUnwrap(PinnedPersonasStore.decode(data1))
    let data2 = try XCTUnwrap(PinnedPersonasStore.encode(decoded))
    XCTAssertEqual(data1, data2)
  }

  func testPackDirectoryNamingPrefersNameThenId() throws {
    let pack = PackMeta(id: "pack.id", name: "My Pack", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: pack), "My Pack")

    let fallback = PackMeta(id: "fallback.id", name: "   ", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: fallback), "fallback.id")

    let sanitized = PackMeta(id: "pack/id", name: "My/Pack", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: sanitized), "My-Pack")
  }

  func testUniquePackDirectoryNameAddsSuffix() throws {
    let existing: Set<String> = ["Pack", "Pack 2", "Pack 3"]
    let name = PersonaPadStorage.uniquePackDirectoryName(preferred: "Pack", existing: existing)
    XCTAssertEqual(name, "Pack 4")
  }

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
