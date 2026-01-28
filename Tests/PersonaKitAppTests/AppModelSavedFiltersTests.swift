import Dependencies
import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("AppModel Saved Filters")
struct AppModelSavedFiltersTests {
  @Test("Save rename delete saved filters")
  @MainActor
  func saveRenameDeleteSavedFilters() throws {
    let fileClient = inMemoryFileClient()
    let filtersURL = URL(fileURLWithPath: "/tmp/personakit-tests/filters.json")
    let pinsURL = URL(fileURLWithPath: "/tmp/personakit-tests/pins.json")
    let savedFiltersStore = SavedFiltersStore(fileURL: filtersURL, fileClient: fileClient)
    let pinnedPersonasStore = PinnedPersonasStore(fileURL: pinsURL, fileClient: fileClient)
    let model = makeModel(
      fileClient: fileClient,
      savedFiltersStore: savedFiltersStore,
      pinnedPersonasStore: pinnedPersonasStore
    )

    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      model.sidebar.searchText = "build determinism"
      model.sidebar.activeFilterTags = ["beta", "alpha", "beta"]
      model.sidebar.activeSourceKinds = [.user, .builtIn]
      model.sidebar.isPinnedViewActive = true

      model.sidebar.saveCurrentFilter(name: "  My Filter  ")
      let saved = try #require(model.sidebar.savedFilters.first)
      #expect(saved.name == "My Filter")
      #expect(saved.queryText == "build determinism")
      #expect(saved.selectedTags == ["alpha", "beta"])
      #expect(saved.selectedSources == ["builtIn", "user"])
      #expect(model.sidebar.selectedSavedFilterID == saved.id)
      #expect(model.sidebar.isPinnedViewActive == false)
      #expect(savedFiltersStore.load() == model.sidebar.savedFilters)

      let savedID = saved.id
      model.sidebar.renameSavedFilter(id: savedID, newName: " Renamed ")
      let renamed = try #require(model.sidebar.savedFilters.first)
      #expect(renamed.name == "Renamed")
      #expect(savedFiltersStore.load() == model.sidebar.savedFilters)

      model.sidebar.selectedSavedFilterID = renamed.id
      model.sidebar.deleteSavedFilter(id: savedID)
      #expect(model.sidebar.savedFilters.isEmpty)
      #expect(model.sidebar.selectedSavedFilterID == nil)
      #expect(savedFiltersStore.load().isEmpty)
    }
  }

  @Test("Apply saved filters updates selection and search state")
  @MainActor
  func applySavedFiltersUpdatesSelectionAndSearchState() {
    let fileClient = inMemoryFileClient()
    let model = makeModel(
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

    model.sidebar.isPinnedViewActive = true
    model.sidebar.applySavedFilter(filter)
    #expect(model.sidebar.selectedSavedFilterID == "filter-1")
    #expect(model.sidebar.searchText == "ios")
    #expect(model.sidebar.activeFilterTags == ["tag-a"])
    #expect(model.sidebar.selectedTag == "tag-a")
    #expect(model.sidebar.activeSourceKinds == [.user])
    #expect(model.sidebar.isPinnedViewActive == false)

    model.sidebar.searchText = "keep"
    model.sidebar.activeFilterTags = ["tag-a"]
    model.sidebar.selectedTag = "tag-a"
    model.sidebar.activeSourceKinds = [.user]
    model.sidebar.isPinnedViewActive = true

    model.sidebar.applyAllPersonasFilter()
    #expect(model.sidebar.selectedSavedFilterID == SidebarModel.allPersonasFilterID)
    #expect(model.sidebar.searchText.isEmpty)
    #expect(model.sidebar.activeFilterTags.isEmpty)
    #expect(model.sidebar.selectedTag == nil)
    #expect(model.sidebar.activeSourceKinds.isEmpty)
    #expect(model.sidebar.isPinnedViewActive == false)
  }

  @MainActor
  private func makeModel(
    fileClient: FileClient,
    savedFiltersStore: SavedFiltersStore,
    pinnedPersonasStore: PinnedPersonasStore
  ) -> AppModel {
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
      AppModel(savedFiltersStore: savedFiltersStore, pinnedPersonasStore: pinnedPersonasStore)
    }
  }
}
