import Foundation

/// Actions to take when handling an escape key event in the sidebar search.
enum SidebarSearchEscapeAction: Equatable {
  case clearAndFocus
  case blur
  case noOp
}

/// Decision rules for how the sidebar search should react to escape.
enum SidebarSearchEscapePolicy {
  /// Returns the escape action based on current text and focus state.
  static func action(searchText: String, isFocused: Bool) -> SidebarSearchEscapeAction {
    if !searchText.isEmpty {
      return .clearAndFocus
    }
    if isFocused {
      return .blur
    }
    return .noOp
  }
}
