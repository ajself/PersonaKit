import ContextWorkspaceCore

enum RelationshipMapPresentationState {
  static func visibleLaneKinds(
    map: WorkspaceSessionMap,
    laneOrder: [WorkspaceSessionMapNodeKind],
    showsEmptyLanes: Bool
  ) -> [WorkspaceSessionMapNodeKind] {
    guard !showsEmptyLanes else {
      return laneOrder
    }

    let populatedKinds = Set(map.nodes.map(\.kind))

    return laneOrder.filter { populatedKinds.contains($0) }
  }

  /// Badges on a node card. A node whose entity isn't in the workspace leads with "missing",
  /// so the state reads in text and not only through the card's red tint.
  static func nodeBadges(_ node: WorkspaceSessionMapNode) -> [String] {
    (node.isMissing ? ["missing"] : []) + node.badges.sorted()
  }

  static func nodeAccessibilityLabel(
    _ node: WorkspaceSessionMapNode,
    scope: WorkspaceSourceScope?
  ) -> String {
    var parts = [
      node.kind.title,
      node.id,
    ]

    if node.displayName != node.id {
      parts.append(node.displayName)
    }

    if let scope {
      parts.append(scope.displayName)
    }

    let badges = nodeBadges(node)

    if !badges.isEmpty {
      parts.append(badges.joined(separator: ", "))
    }

    return parts.joined(separator: ", ")
  }
}

extension WorkspaceSessionMapNodeKind {
  var title: String {
    switch self {
    case .session:
      return "Session"
    case .persona:
      return "Persona"
    case .directive:
      return "Directive"
    case .kit:
      return "Kits"
    case .skill:
      return "Skills"
    }
  }
}
