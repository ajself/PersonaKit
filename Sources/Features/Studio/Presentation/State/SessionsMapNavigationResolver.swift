import ContextWorkspaceCore

/// Shared map-node navigation resolver used by Studio relationship map surfaces.
enum SessionsMapNavigationResolver {
  static func navigationTarget(
    for node: WorkspaceSessionMapNode,
    selectedSessionID: String?
  ) -> StudioNavigationTarget? {
    switch node.kind {
    case .session:
      guard
        let selectedSessionID,
        selectedSessionID != "active-session"
      else {
        return nil
      }

      return StudioNavigationTarget(
        sidebarItem: .sessions,
        selectedSessionID: selectedSessionID,
        searchText: ""
      )

    case .persona:
      return StudioNavigationTarget(
        sidebarItem: .personas,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .directive:
      return StudioNavigationTarget(
        sidebarItem: .directives,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .kit:
      return StudioNavigationTarget(
        sidebarItem: .kits,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .intent:
      return StudioNavigationTarget(
        sidebarItem: .intents,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .skill:
      return StudioNavigationTarget(
        sidebarItem: .skills,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .essential:
      return StudioNavigationTarget(
        sidebarItem: .essentials,
        selectedLibraryItemID: node.id,
        searchText: ""
      )

    case .reference:
      return StudioNavigationTarget(
        sidebarItem: .references,
        selectedLibraryItemID: node.id,
        searchText: ""
      )
    }
  }
}
