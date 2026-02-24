/// Root-level navigation state updated by sessions/relationship-map drill-down actions.
struct StudioRootNavigationState: Equatable, Sendable {
  var selection: SidebarItem?
  var selectedLibraryItemID: String?
  var searchText: String

  mutating func apply(_ target: SessionsNavigationTarget) {
    selection = target.sidebarItem
    selectedLibraryItemID = target.selectedLibraryItemID
    searchText = target.searchText
  }
}
