import Foundation

enum SidebarSearchEscapeAction: Equatable {
  case clearAndFocus
  case blur
  case noOp
}

struct SidebarSearchEscapePolicy {
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
