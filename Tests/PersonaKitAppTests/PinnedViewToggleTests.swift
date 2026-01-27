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
    let model = makeModel()

    #expect(model.sidebar.isPinnedViewActive == false)

    model.sidebar.togglePinnedView()
    #expect(model.sidebar.isPinnedViewActive == true)

    model.sidebar.togglePinnedView()
    #expect(model.sidebar.isPinnedViewActive == false)
  }

  @Test("Unpinning last persona disables pinned view")
  @MainActor
  func unpinningLastPersonaDisablesPinnedView() {
    let model = makeModel()
    model.sidebar.togglePinnedPersona(id: "persona-1")
    model.sidebar.togglePinnedView()

    #expect(model.sidebar.isPinnedViewActive == true)

    model.sidebar.togglePinnedPersona(id: "persona-1")
    #expect(model.sidebar.pinnedPersonaIDs.isEmpty)
    #expect(model.sidebar.isPinnedViewActive == false)
  }

  @MainActor
  private func makeModel() -> AppModel {
    withDependencies {
      $0.fileClient = inMemoryFileClient()
    } operation: {
      AppModel()
    }
  }
}
