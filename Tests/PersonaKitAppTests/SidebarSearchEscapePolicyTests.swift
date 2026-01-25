import Testing

@testable import PersonaKitApp

@Suite("Sidebar Search Escape Policy")
struct SidebarSearchEscapePolicyTests {
  @Test("Escape clears and focuses when search has text")
  func escapeClearsAndFocusesWhenSearchHasText() {
    let action = SidebarSearchEscapePolicy.action(searchText: "swift", isFocused: false)
    #expect(action == .clearAndFocus)
  }

  @Test("Escape blurs when focused and empty")
  func escapeBlursWhenFocusedAndEmpty() {
    let action = SidebarSearchEscapePolicy.action(searchText: "", isFocused: true)
    #expect(action == .blur)
  }

  @Test("Escape no-op when not focused and empty")
  func escapeNoOpWhenNotFocusedAndEmpty() {
    let action = SidebarSearchEscapePolicy.action(searchText: "", isFocused: false)
    #expect(action == .noOp)
  }
}
