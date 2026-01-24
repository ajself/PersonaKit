import Foundation

enum SidebarSearchEscapeAction: Equatable {
  case clearAndFocus
  case blur
  case noOp
}

enum SidebarSearchEscapePolicy {
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
