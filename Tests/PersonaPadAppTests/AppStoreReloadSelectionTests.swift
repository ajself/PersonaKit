import Dependencies
import Foundation
import PersonaPadCore
import Testing

@testable import PersonaPadApp

@Suite("AppStore Reload Selection")
struct AppStoreReloadSelectionTests {
  @Test("Reload preserves selection when persona exists")
  @MainActor
  func reloadPreservesSelectionWhenPersonaExists() throws {
    let store = makeStore()
    store.send(.reloadAll)

    let ids = store.state.personaIndex.keys.sorted()
    let selected = try #require(ids.last)
    store.send(.setSelectedPersonaID(selected))

    store.send(.reloadAll)
    #expect(store.state.selectedPersonaID == selected)
  }

  @Test("Reload falls back to first persona when selection missing")
  @MainActor
  func reloadFallsBackWhenSelectionMissing() throws {
    let store = makeStore()
    store.send(.reloadAll)

    store.state.selectedPersonaID = "missing-persona-id"
    store.send(.reloadAll)

    let expected = try #require(store.state.personaIndex.keys.sorted().first)
    #expect(store.state.selectedPersonaID == expected)
  }

  @MainActor
  private func makeStore() -> AppStore {
    let fileClient = inMemoryFileClient()
    let filtersURL = URL(fileURLWithPath: "/tmp/personapad-tests/filters.json")
    let pinsURL = URL(fileURLWithPath: "/tmp/personapad-tests/pins.json")
    let savedFiltersStore = SavedFiltersStore(fileURL: filtersURL, fileClient: fileClient)
    let pinnedPersonasStore = PinnedPersonasStore(fileURL: pinsURL, fileClient: fileClient)
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
    } operation: {
      AppStore(savedFiltersStore: savedFiltersStore, pinnedPersonasStore: pinnedPersonasStore)
    }
  }
}
