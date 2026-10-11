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
}
