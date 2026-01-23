import XCTest
@testable import PersonaPadApp

final class SidebarSearchEscapePolicyTests: XCTestCase {
  func testEscapeClearsAndFocusesWhenSearchHasText() {
    let action = SidebarSearchEscapePolicy.action(searchText: "swift", isFocused: false)
    XCTAssertEqual(action, .clearAndFocus)
  }

  func testEscapeBlursWhenFocusedAndEmpty() {
    let action = SidebarSearchEscapePolicy.action(searchText: "", isFocused: true)
    XCTAssertEqual(action, .blur)
  }

  func testEscapeNoOpWhenNotFocusedAndEmpty() {
    let action = SidebarSearchEscapePolicy.action(searchText: "", isFocused: false)
    XCTAssertEqual(action, .noOp)
  }
}
