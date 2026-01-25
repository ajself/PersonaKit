import Foundation
import Testing

@testable import PersonaKitCore

@Suite("PersonaKitCore Storage")
struct PersonaKitCoreStorageTests {
  @Test("Pack diff classifies and sorts deterministically")
  func packDiffClassifiesAndSortsDeterministically() {
    var left: [PersonaDiffRecord] = []
    left.append(PersonaDiffRecord(key: "z", id: "zeta", name: "Zeta", contentHash: "a"))
    left.append(PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"))
    left.append(PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha", contentHash: "c"))

    var right: [PersonaDiffRecord] = []
    right.append(PersonaDiffRecord(key: "b", id: "beta", name: "Beta", contentHash: "b"))
    right.append(PersonaDiffRecord(key: "a", id: "alpha", name: "Alpha Updated", contentHash: "d"))
    right.append(PersonaDiffRecord(key: "c", id: "charlie", name: "Charlie", contentHash: "e"))

    let diff = PackDiffBuilder.diff(left: Array(left.reversed()), right: Array(right.reversed()))

    #expect(diff.added.map(\.id) == ["charlie"])
    #expect(diff.removed.map(\.id) == ["zeta"])
    #expect(diff.modified.map(\.id) == ["alpha"])

    var addedRight: [PersonaDiffRecord] = []
    addedRight.append(PersonaDiffRecord(key: "b", id: "b", name: "Beta", contentHash: "1"))
    addedRight.append(PersonaDiffRecord(key: "a", id: "a", name: "Alpha", contentHash: "1"))
    let addedDiff = PackDiffBuilder.diff(left: [], right: addedRight)
    #expect(addedDiff.added.map(\.id) == ["a", "b"])
  }

  @Test("Storage paths are deterministic")
  func storagePathsAreDeterministic() {
    let home = URL(fileURLWithPath: "/Users/tester")
    let paths = PersonaKitStoragePaths.standard(homeDirectory: home)
    #expect(paths.root.path == "/Users/tester/Library/Application Support/PersonaKit")
    #expect(paths.packs.path == "/Users/tester/Library/Application Support/PersonaKit/Packs")
    #expect(paths.state.path == "/Users/tester/Library/Application Support/PersonaKit/State")
  }

  @Test("Saved filters round trip deterministic encoding")
  func savedFiltersRoundTripDeterministicEncoding() throws {
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

    let data1 = try #require(SavedFiltersStore.encode(filters))
    let decoded = try #require(SavedFiltersStore.decode(data1))
    let data2 = try #require(SavedFiltersStore.encode(decoded))
    #expect(data1 == data2)
  }

  @Test("Saved filters load sorts by name then id")
  func savedFiltersLoadSortsByNameThenId() {
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
    #expect(loaded.map(\.id) == ["a1", "a2", "b2"])
  }

  @Test("Pinned personas missing file returns empty")
  func pinnedPersonasMissingFileReturnsEmpty() {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("pins.json")
    let store = PinnedPersonasStore(fileURL: fileURL)

    #expect(store.load() == [])
  }

  @Test("Pinned personas save sorts deterministically")
  func pinnedPersonasSaveSortsDeterministically() {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let fileURL = tempRoot.appendingPathComponent("pins.json")
    let store = PinnedPersonasStore(fileURL: fileURL)

    store.save(["zeta", "alpha", "beta"])
    let loaded = store.load()
    #expect(loaded == ["alpha", "beta", "zeta"])
  }

  @Test("Pinned personas round trip deterministic encoding")
  func pinnedPersonasRoundTripDeterministicEncoding() throws {
    let pins = ["beta", "alpha"]
    let data1 = try #require(PinnedPersonasStore.encode(pins))
    let decoded = try #require(PinnedPersonasStore.decode(data1))
    let data2 = try #require(PinnedPersonasStore.encode(decoded))
    #expect(data1 == data2)
  }

  @Test("Pack directory naming prefers name then id")
  func packDirectoryNamingPrefersNameThenId() {
    let pack = PackMeta(
      id: "pack.id", name: "My Pack", author: nil, description: nil, homepage: nil)
    #expect(PersonaKitStorage.preferredPackDirectoryName(for: pack) == "My Pack")

    let fallback = PackMeta(
      id: "fallback.id", name: "   ", author: nil, description: nil, homepage: nil)
    #expect(PersonaKitStorage.preferredPackDirectoryName(for: fallback) == "fallback.id")

    let sanitized = PackMeta(
      id: "pack/id", name: "My/Pack", author: nil, description: nil, homepage: nil)
    #expect(PersonaKitStorage.preferredPackDirectoryName(for: sanitized) == "My-Pack")
  }

  @Test("Unique pack directory name adds suffix")
  func uniquePackDirectoryNameAddsSuffix() {
    let existing: Set<String> = ["Pack", "Pack 2", "Pack 3"]
    let name = PersonaKitStorage.uniquePackDirectoryName(preferred: "Pack", existing: existing)
    #expect(name == "Pack 4")
  }
}
