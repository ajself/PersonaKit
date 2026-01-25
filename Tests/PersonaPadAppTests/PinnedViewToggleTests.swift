import Dependencies
import Foundation
import PersonaPadCore
import Testing

@testable import PersonaPadApp

@Suite("Pinned View Toggle")
struct PinnedViewToggleTests {
  @Test("Pinned view toggles on and off")
  @MainActor
  func pinnedViewTogglesOnAndOff() {
    let store = makeStore()

    #expect(store.state.isPinnedViewActive == false)

    store.send(.setPinnedViewActive)
    #expect(store.state.isPinnedViewActive == true)

    store.send(.setPinnedViewActive)
    #expect(store.state.isPinnedViewActive == false)
  }

  @Test("Unpinning last persona disables pinned view")
  @MainActor
  func unpinningLastPersonaDisablesPinnedView() {
    let store = makeStore()
    store.send(.togglePinnedPersona(id: "persona-1"))
    store.send(.setPinnedViewActive)

    #expect(store.state.isPinnedViewActive == true)

    store.send(.togglePinnedPersona(id: "persona-1"))
    #expect(store.state.pinnedPersonaIDs.isEmpty)
    #expect(store.state.isPinnedViewActive == false)
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
