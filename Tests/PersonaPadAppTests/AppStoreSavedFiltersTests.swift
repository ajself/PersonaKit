import Dependencies
import Foundation
import PersonaPadCore
import Testing

@testable import PersonaPadApp

@Suite("AppStore Saved Filters")
struct AppStoreSavedFiltersTests {
  @Test("Save rename delete saved filters")
  @MainActor
  func saveRenameDeleteSavedFilters() throws {
    let fileClient = inMemoryFileClient()
    let filtersURL = URL(fileURLWithPath: "/tmp/personapad-tests/filters.json")
    let pinsURL = URL(fileURLWithPath: "/tmp/personapad-tests/pins.json")
    let savedFiltersStore = SavedFiltersStore(fileURL: filtersURL, fileClient: fileClient)
    let pinnedPersonasStore = PinnedPersonasStore(fileURL: pinsURL, fileClient: fileClient)
    let store = makeStore(
      fileClient: fileClient,
      savedFiltersStore: savedFiltersStore,
      pinnedPersonasStore: pinnedPersonasStore
    )

    store.state.searchText = "build determinism"
    store.state.activeFilterTags = ["beta", "alpha", "beta"]
    store.state.activeSourceKinds = [.user, .builtIn]
    store.state.isPinnedViewActive = true

    store.send(.saveCurrentFilter(name: "  My Filter  "))
    let saved = try #require(store.state.savedFilters.first)
    #expect(saved.name == "My Filter")
    #expect(saved.queryText == "build determinism")
    #expect(saved.selectedTags == ["alpha", "beta"])
    #expect(saved.selectedSources == ["builtIn", "user"])
    #expect(store.state.selectedSavedFilterID == saved.id)
    #expect(store.state.isPinnedViewActive == false)
    #expect(savedFiltersStore.load() == store.state.savedFilters)

    let savedID = saved.id
    store.send(.renameSavedFilter(id: savedID, newName: " Renamed "))
    let renamed = try #require(store.state.savedFilters.first)
    #expect(renamed.name == "Renamed")
    #expect(savedFiltersStore.load() == store.state.savedFilters)

    store.state.selectedSavedFilterID = renamed.id
    store.send(.deleteSavedFilter(id: savedID))
    #expect(store.state.savedFilters.isEmpty)
    #expect(store.state.selectedSavedFilterID == nil)
    #expect(savedFiltersStore.load().isEmpty)
  }

  @Test("Apply saved filters updates selection and search state")
  @MainActor
  func applySavedFiltersUpdatesSelectionAndSearchState() {
    let fileClient = inMemoryFileClient()
    let store = makeStore(
      fileClient: fileClient,
      savedFiltersStore: SavedFiltersStore(
        fileURL: URL(fileURLWithPath: "/tmp/personapad-tests/filters.json"),
        fileClient: fileClient
      ),
      pinnedPersonasStore: PinnedPersonasStore(
        fileURL: URL(fileURLWithPath: "/tmp/personapad-tests/pins.json"),
        fileClient: fileClient
      )
    )

    let filter = SavedFilter(
      id: "filter-1",
      name: "Focus",
      queryText: "ios",
      selectedTags: ["tag-a"],
      selectedSources: ["user"],
      groupingMode: nil
    )

    store.state.isPinnedViewActive = true
    store.send(.applySavedFilter(filter))
    #expect(store.state.selectedSavedFilterID == "filter-1")
    #expect(store.state.searchText == "ios")
    #expect(store.state.activeFilterTags == ["tag-a"])
    #expect(store.state.selectedTag == "tag-a")
    #expect(store.state.activeSourceKinds == [.user])
    #expect(store.state.isPinnedViewActive == false)

    store.state.searchText = "keep"
    store.state.activeFilterTags = ["tag-a"]
    store.state.selectedTag = "tag-a"
    store.state.activeSourceKinds = [.user]
    store.state.isPinnedViewActive = true

    store.send(.applyAllPersonasFilter)
    #expect(store.state.selectedSavedFilterID == AppStore.allPersonasFilterID)
    #expect(store.state.searchText.isEmpty)
    #expect(store.state.activeFilterTags.isEmpty)
    #expect(store.state.selectedTag == nil)
    #expect(store.state.activeSourceKinds.isEmpty)
    #expect(store.state.isPinnedViewActive == false)
  }

  @MainActor
  private func makeStore(
    fileClient: FileClient,
    savedFiltersStore: SavedFiltersStore,
    pinnedPersonasStore: PinnedPersonasStore
  ) -> AppStore {
    let appClient = AppClient(
      selectPackURL: { nil },
      confirmRemovePack: { false },
      presentError: { _, _ in },
      openURL: { _ in },
      copyToClipboard: { _ in }
    )
    return withDependencies {
      $0.fileClient = fileClient
      $0.appClient = appClient
      $0.uuid = .incrementing
    } operation: {
      AppStore(savedFiltersStore: savedFiltersStore, pinnedPersonasStore: pinnedPersonasStore)
    }
  }
}
