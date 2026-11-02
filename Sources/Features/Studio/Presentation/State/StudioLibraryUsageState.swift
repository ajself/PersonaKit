import ContextWorkspaceCore

/// Derives a library item's "Used by" backlinks from the workspace dependency graph.
///
/// Graph edges point from the referencing item to the item it references
/// (`session -> persona`, `persona -> kit`, `kit -> skill`), so an item's users are the
/// sources of its incoming edges.
enum StudioLibraryUsageState {
  /// The graph key for a library item, matching the builder's `kind:id` node keys.
  static func nodeKey(
    kind: WorkspaceSessionMapNodeKind,
    id: String
  ) -> String {
    "\(kind.rawValue):\(id)"
  }

  /// Nodes with an edge into `nodeKey`, deduplicated and ordered by node kind, then id.
  static func users(
    of nodeKey: String,
    in map: WorkspaceSessionMap
  ) -> [WorkspaceSessionMapNode] {
    let nodesByKey = Dictionary(
      map.nodes.map { ($0.key, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let userKeys = Set(
      map.edges
        .filter { $0.toKey == nodeKey }
        .map(\.fromKey)
    )

    let users = userKeys.compactMap { nodesByKey[$0] }

    return users.sorted { lhs, rhs in
      if lhs.kind != rhs.kind {
        return kindRank(lhs.kind) < kindRank(rhs.kind)
      }

      if lhs.id != rhs.id {
        return lhs.id < rhs.id
      }

      return lhs.key < rhs.key
    }
  }

  /// A "Used by" row's second line: the kind, then the id when the row's title is a distinct name.
  static func rowSubtitle(
    for node: WorkspaceSessionMapNode,
    kindTitle: String
  ) -> String {
    node.displayName == node.id ? kindTitle : "\(kindTitle) · \(node.id)"
  }

  /// A "Used by" row's VoiceOver label, adding the id when it differs so same-named items sound distinct.
  static func rowAccessibilityLabel(
    for node: WorkspaceSessionMapNode,
    kindTitle: String
  ) -> String {
    let name = node.displayName == node.id ? node.id : "\(node.displayName), \(node.id)"

    return "Open \(kindTitle) \(name)"
  }

  private static func kindRank(_ kind: WorkspaceSessionMapNodeKind) -> Int {
    switch kind {
    case .session:
      return 0
    case .persona:
      return 1
    case .directive:
      return 2
    case .kit:
      return 3
    case .skill:
      return 4
    }
  }
}

extension SidebarItem {
  /// The graph node kind for a library section's items; `nil` for non-library sections.
  var libraryNodeKind: WorkspaceSessionMapNodeKind? {
    switch self {
    case .personas:
      return .persona
    case .directives:
      return .directive
    case .kits:
      return .kit
    case .skills:
      return .skill
    case .sessions,
      .validationResults:
      return nil
    }
  }
}
