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

    store.sidebar.searchText = "build determinism"
    store.sidebar.activeFilterTags = ["beta", "alpha", "beta"]
    store.sidebar.activeSourceKinds = [.user, .builtIn]
    store.sidebar.isPinnedViewActive = true

    store.sidebar.saveCurrentFilter(name: "  My Filter  ")
    let saved = try #require(store.sidebar.savedFilters.first)
    #expect(saved.name == "My Filter")
    #expect(saved.queryText == "build determinism")
    #expect(saved.selectedTags == ["alpha", "beta"])
    #expect(saved.selectedSources == ["builtIn", "user"])
    #expect(store.sidebar.selectedSavedFilterID == saved.id)
    #expect(store.sidebar.isPinnedViewActive == false)
    #expect(savedFiltersStore.load() == store.sidebar.savedFilters)

    let savedID = saved.id
    store.sidebar.renameSavedFilter(id: savedID, newName: " Renamed ")
    let renamed = try #require(store.sidebar.savedFilters.first)
    #expect(renamed.name == "Renamed")
    #expect(savedFiltersStore.load() == store.sidebar.savedFilters)

    store.sidebar.selectedSavedFilterID = renamed.id
    store.sidebar.deleteSavedFilter(id: savedID)
    #expect(store.sidebar.savedFilters.isEmpty)
    #expect(store.sidebar.selectedSavedFilterID == nil)
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

    store.sidebar.isPinnedViewActive = true
    store.sidebar.applySavedFilter(filter)
    #expect(store.sidebar.selectedSavedFilterID == "filter-1")
    #expect(store.sidebar.searchText == "ios")
    #expect(store.sidebar.activeFilterTags == ["tag-a"])
    #expect(store.sidebar.selectedTag == "tag-a")
    #expect(store.sidebar.activeSourceKinds == [.user])
    #expect(store.sidebar.isPinnedViewActive == false)

    store.sidebar.searchText = "keep"
    store.sidebar.activeFilterTags = ["tag-a"]
    store.sidebar.selectedTag = "tag-a"
    store.sidebar.activeSourceKinds = [.user]
    store.sidebar.isPinnedViewActive = true

    store.sidebar.applyAllPersonasFilter()
    #expect(store.sidebar.selectedSavedFilterID == SidebarModel.allPersonasFilterID)
    #expect(store.sidebar.searchText.isEmpty)
    #expect(store.sidebar.activeFilterTags.isEmpty)
    #expect(store.sidebar.selectedTag == nil)
    #expect(store.sidebar.activeSourceKinds.isEmpty)
    #expect(store.sidebar.isPinnedViewActive == false)
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
