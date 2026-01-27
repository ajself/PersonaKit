import Dependencies
import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("AppStore Saved Filters")
struct AppStoreSavedFiltersTests {
  @Test("Save rename delete saved filters")
  @MainActor
  func saveRenameDeleteSavedFilters() throws {
    let fileClient = inMemoryFileClient()
    let filtersURL = URL(fileURLWithPath: "/tmp/personakit-tests/filters.json")
    let pinsURL = URL(fileURLWithPath: "/tmp/personakit-tests/pins.json")
    let savedFiltersStore = SavedFiltersStore(fileURL: filtersURL, fileClient: fileClient)
    let pinnedPersonasStore = PinnedPersonasStore(fileURL: pinsURL, fileClient: fileClient)
    let store = makeStore(
      fileClient: fileClient,
      savedFiltersStore: savedFiltersStore,
      pinnedPersonasStore: pinnedPersonasStore
    )

    store.state.sidebar.searchText = "build determinism"
    store.state.sidebar.activeFilterTags = ["beta", "alpha", "beta"]
    store.state.sidebar.activeSourceKinds = [.user, .builtIn]
    store.state.sidebar.isPinnedViewActive = true

    store.send(.sidebar(.saveCurrentFilter(name: "  My Filter  ")))
    let saved = try #require(store.state.sidebar.savedFilters.first)
    #expect(saved.name == "My Filter")
    #expect(saved.queryText == "build determinism")
    #expect(saved.selectedTags == ["alpha", "beta"])
    #expect(saved.selectedSources == ["builtIn", "user"])
    #expect(store.state.sidebar.selectedSavedFilterID == saved.id)
    #expect(store.state.sidebar.isPinnedViewActive == false)
    #expect(savedFiltersStore.load() == store.state.sidebar.savedFilters)

    let savedID = saved.id
    store.send(.sidebar(.renameSavedFilter(id: savedID, newName: " Renamed ")))
    let renamed = try #require(store.state.sidebar.savedFilters.first)
    #expect(renamed.name == "Renamed")
    #expect(savedFiltersStore.load() == store.state.sidebar.savedFilters)

    store.state.sidebar.selectedSavedFilterID = renamed.id
    store.send(.sidebar(.deleteSavedFilter(id: savedID)))
    #expect(store.state.sidebar.savedFilters.isEmpty)
    #expect(store.state.sidebar.selectedSavedFilterID == nil)
    #expect(savedFiltersStore.load().isEmpty)
  }

  @Test("Apply saved filters updates selection and search state")
  @MainActor
  func applySavedFiltersUpdatesSelectionAndSearchState() {
    let fileClient = inMemoryFileClient()
    let store = makeStore(
      fileClient: fileClient,
      savedFiltersStore: SavedFiltersStore(
        fileURL: URL(fileURLWithPath: "/tmp/personakit-tests/filters.json"),
        fileClient: fileClient
      ),
      pinnedPersonasStore: PinnedPersonasStore(
        fileURL: URL(fileURLWithPath: "/tmp/personakit-tests/pins.json"),
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

    store.state.sidebar.isPinnedViewActive = true
    store.send(.sidebar(.applySavedFilter(filter)))
    #expect(store.state.sidebar.selectedSavedFilterID == "filter-1")
    #expect(store.state.sidebar.searchText == "ios")
    #expect(store.state.sidebar.activeFilterTags == ["tag-a"])
    #expect(store.state.sidebar.selectedTag == "tag-a")
    #expect(store.state.sidebar.activeSourceKinds == [.user])
    #expect(store.state.sidebar.isPinnedViewActive == false)

    store.state.sidebar.searchText = "keep"
    store.state.sidebar.activeFilterTags = ["tag-a"]
    store.state.sidebar.selectedTag = "tag-a"
    store.state.sidebar.activeSourceKinds = [.user]
    store.state.sidebar.isPinnedViewActive = true

    store.send(.sidebar(.applyAllPersonasFilter))
    #expect(store.state.sidebar.selectedSavedFilterID == SidebarFeature.allPersonasFilterID)
    #expect(store.state.sidebar.searchText.isEmpty)
    #expect(store.state.sidebar.activeFilterTags.isEmpty)
    #expect(store.state.sidebar.selectedTag == nil)
    #expect(store.state.sidebar.activeSourceKinds.isEmpty)
    #expect(store.state.sidebar.isPinnedViewActive == false)
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
