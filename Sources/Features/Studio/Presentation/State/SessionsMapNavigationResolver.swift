import ContextWorkspaceCore

/// Shared map-node navigation resolver used by Studio relationship map surfaces.
enum SessionsMapNavigationResolver {
  static func navigationTarget(
    for node: WorkspaceSessionMapNode,
    selectedSessionID: String?
  ) -> SessionsNavigationTarget? {
    switch node.kind {
    case .session:
      guard
        let selectedSessionID,
        selectedSessionID != "active-session"
      else {
        return nil
      }

      return SessionsNavigationTarget(
        sidebarItem: .sessions,
        selectedLibraryItemID: nil,
        searchText: selectedSessionID
      )

    case .persona:
      return SessionsNavigationTarget(
        sidebarItem: .personas,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .directive:
      return SessionsNavigationTarget(
        sidebarItem: .directives,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .kit:
      return SessionsNavigationTarget(
        sidebarItem: .kits,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .intent:
      return SessionsNavigationTarget(
        sidebarItem: .intents,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .skill:
      return SessionsNavigationTarget(
        sidebarItem: .skills,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .essential:
      return SessionsNavigationTarget(
        sidebarItem: .essentials,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )

    case .reference:
      return SessionsNavigationTarget(
        sidebarItem: .references,
        selectedLibraryItemID: node.id,
        searchText: node.id
      )
    }
  }
}
