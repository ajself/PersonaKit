import Dependencies
import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("Pinned View Toggle")
struct PinnedViewToggleTests {
  @Test("Pinned view toggles on and off")
  @MainActor
  func pinnedViewTogglesOnAndOff() {
    let store = makeStore()

    #expect(store.sidebar.isPinnedViewActive == false)

    store.sidebar.togglePinnedView()
    #expect(store.sidebar.isPinnedViewActive == true)

    store.sidebar.togglePinnedView()
    #expect(store.sidebar.isPinnedViewActive == false)
  }

  @Test("Unpinning last persona disables pinned view")
  @MainActor
  func unpinningLastPersonaDisablesPinnedView() {
    let store = makeStore()
    store.sidebar.togglePinnedPersona(id: "persona-1")
    store.sidebar.togglePinnedView()

    #expect(store.sidebar.isPinnedViewActive == true)

    store.sidebar.togglePinnedPersona(id: "persona-1")
    #expect(store.sidebar.pinnedPersonaIDs.isEmpty)
    #expect(store.sidebar.isPinnedViewActive == false)
  }

  @MainActor
  private func makeStore() -> AppStore {
    withDependencies {
      $0.fileClient = inMemoryFileClient()
    } operation: {
      AppStore()
    }
  }
}
