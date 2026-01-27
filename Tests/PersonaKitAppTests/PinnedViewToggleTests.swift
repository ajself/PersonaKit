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

    #expect(store.state.sidebar.isPinnedViewActive == false)

    store.send(.sidebar(.setPinnedViewActive))
    #expect(store.state.sidebar.isPinnedViewActive == true)

    store.send(.sidebar(.setPinnedViewActive))
    #expect(store.state.sidebar.isPinnedViewActive == false)
  }

  @Test("Unpinning last persona disables pinned view")
  @MainActor
  func unpinningLastPersonaDisablesPinnedView() {
    let store = makeStore()
    store.send(.sidebar(.togglePinnedPersona(id: "persona-1")))
    store.send(.sidebar(.setPinnedViewActive))

    #expect(store.state.sidebar.isPinnedViewActive == true)

    store.send(.sidebar(.togglePinnedPersona(id: "persona-1")))
    #expect(store.state.sidebar.pinnedPersonaIDs.isEmpty)
    #expect(store.state.sidebar.isPinnedViewActive == false)
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
