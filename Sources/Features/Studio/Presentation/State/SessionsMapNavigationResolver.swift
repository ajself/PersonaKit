import ContextWorkspaceCore

/// Shared map-node navigation resolver used by Studio session map surfaces.
enum SessionsMapNavigationResolver {
  static func navigationTarget(for node: WorkspaceSessionMapNode) -> StudioNavigationTarget {
    switch node.kind {
    case .session:
      return StudioNavigationTarget(
        sidebarItem: .sessions,
        selectedSessionID: node.id,
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

    case .skill:
      return StudioNavigationTarget(
        sidebarItem: .skills,
        selectedLibraryItemID: node.id,
        searchText: ""
      )
    }
  }
}
