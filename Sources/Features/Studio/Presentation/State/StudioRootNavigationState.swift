/// Cross-panel navigation request emitted by Studio views.
struct StudioNavigationTarget: Equatable, Sendable {
  let sidebarItem: SidebarItem
  let selectedLibraryItemID: String?
  let selectedSessionID: String?
  let searchText: String?

  init(
    sidebarItem: SidebarItem,
    selectedLibraryItemID: String? = nil,
    selectedSessionID: String? = nil,
    searchText: String? = nil
  ) {
    self.sidebarItem = sidebarItem
    self.selectedLibraryItemID = selectedLibraryItemID
    self.selectedSessionID = selectedSessionID
    self.searchText = searchText
  }
}

/// Root-level navigation state updated by explicit Studio navigation actions.
struct StudioRootNavigationState: Equatable, Sendable {
  var selection: SidebarItem?
  var selectedLibraryItemID: String?
  var selectedSessionID: String?
  var searchTextBySidebarItem: [SidebarItem: String]

  mutating func apply(_ target: StudioNavigationTarget) {
    selection = target.sidebarItem

    if target.sidebarItem == .sessions,
      let targetSessionID = target.selectedSessionID
    {
      selectedSessionID = targetSessionID
    }

    if target.sidebarItem.isLibrarySection {
      selectedLibraryItemID = target.selectedLibraryItemID
    } else {
      selectedLibraryItemID = nil
    }

    if let searchText = target.searchText {
      searchTextBySidebarItem[target.sidebarItem] = searchText
    }
  }
}

extension SidebarItem {
  var isLibrarySection: Bool {
    switch self {
    case .personas,
      .directives,
      .kits,
      .skills:
      return true
    case .sessions,
      .relationshipMap,
      .validationResults:
      return false
    }
  }
}
