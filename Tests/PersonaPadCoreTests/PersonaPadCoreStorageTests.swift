import XCTest

@testable import PersonaPadCore

final class PersonaPadCoreStorageTests: XCTestCase {
  func testPackDiffClassifiesAndSortsDeterministically() throws {
    var left: [PersonaDiffRecord] = []
    left.append(PersonaDiffRecord(key: "z", id: "zeta", name: "Zeta", contentHash: "a"))
    left.append(PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"))
    left.append(PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha", contentHash: "c"))

    var right: [PersonaDiffRecord] = []
    right.append(PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"))
    right.append(PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha Updated", contentHash: "d"))
    right.append(PersonaDiffRecord(key: "c", id: "charlie", name: "Charlie", contentHash: "e"))

    let diff = PackDiffBuilder.diff(left: Array(left.reversed()), right: Array(right.reversed()))

    XCTAssertEqual(diff.added.map(\.id), ["charlie"])
    XCTAssertEqual(diff.removed.map(\.id), ["zeta"])
    XCTAssertEqual(diff.modified.map(\.id), ["alpha"])

    var addedRight: [PersonaDiffRecord] = []
    addedRight.append(PersonaDiffRecord(key: "b", id: "b", name: "Beta", contentHash: "1"))
    addedRight.append(PersonaDiffRecord(key: "a", id: "a", name: "Alpha", contentHash: "1"))
    let addedDiff = PackDiffBuilder.diff(left: [], right: addedRight)
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
    var filters: [SavedFilter] = []
    filters.append(
      SavedFilter(
        id: "b",
        name: "Beta",
        queryText: "beta",
        selectedTags: ["tag-b"],
        selectedSources: ["user"],
        groupingMode: nil
      )
    )
    filters.append(
      SavedFilter(
        id: "a",
        name: "Alpha",
        queryText: "alpha",
        selectedTags: ["tag-a"],
        selectedSources: ["builtIn"],
        groupingMode: "tag"
      )
    )

    let data1 = try XCTUnwrap(SavedFiltersStore.encode(filters))
    let decoded = try XCTUnwrap(SavedFiltersStore.decode(data1))
    let data2 = try XCTUnwrap(SavedFiltersStore.encode(decoded))
    XCTAssertEqual(data1, data2)
  }

  func testSavedFiltersLoadSortsByNameThenId() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("filters.json")
    let store = SavedFiltersStore(fileURL: fileURL)

    var filters: [SavedFilter] = []
    filters.append(
      SavedFilter(
        id: "b2",
        name: "Beta",
        queryText: "beta",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      )
    )
    filters.append(
      SavedFilter(
        id: "a2",
        name: "Alpha",
        queryText: "alpha-2",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      )
    )
    filters.append(
      SavedFilter(
        id: "a1",
        name: "Alpha",
        queryText: "alpha-1",
        selectedTags: [],
        selectedSources: [],
        groupingMode: nil
      )
    )

    store.save(filters)
    let loaded = store.load()
    XCTAssertEqual(loaded.map(\.id), ["a1", "a2", "b2"])
  }

  func testPinnedPersonasMissingFileReturnsEmpty() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("pins.json")
    let store = PinnedPersonasStore(fileURL: fileURL)

    XCTAssertEqual(store.load(), [])
  }

  func testPinnedPersonasSaveSortsDeterministically() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
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
    let pack = PackMeta(
      id: "pack.id", name: "My Pack", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: pack), "My Pack")

    let fallback = PackMeta(
      id: "fallback.id", name: "   ", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: fallback), "fallback.id")

    let sanitized = PackMeta(
      id: "pack/id", name: "My/Pack", author: nil, description: nil, homepage: nil)
    XCTAssertEqual(PersonaPadStorage.preferredPackDirectoryName(for: sanitized), "My-Pack")
  }

  func testUniquePackDirectoryNameAddsSuffix() throws {
    let existing: Set<String> = ["Pack", "Pack 2", "Pack 3"]
    let name = PersonaPadStorage.uniquePackDirectoryName(preferred: "Pack", existing: existing)
    XCTAssertEqual(name, "Pack 4")
  }
}
