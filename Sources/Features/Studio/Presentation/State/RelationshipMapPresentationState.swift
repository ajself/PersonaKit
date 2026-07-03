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

  static func reasonLabel(
    for reason: String
  ) -> String {
    switch reason {
    case "session.personaId":
      return "session persona"
    case "session.directiveId":
      return "session directive"
    case "session.kitOverrides":
      return "session kit override"
    case "persona.defaultKitIds":
      return "default kit"
    case "directive.requiresSkillIds":
      return "directive requires skill"
    case "kit.skillIds":
      return "kit skill"
    case "kit.essentialIds":
      return "kit essential"
    default:
      return reason
    }
  }

  static func relationshipSummaries(
    map: WorkspaceSessionMap
  ) -> [String] {
    let nodesByKey = Dictionary(uniqueKeysWithValues: map.nodes.map { ($0.key, $0) })

    let summaries: [String] = map.edges.compactMap { edge in
      guard let fromNode = nodesByKey[edge.fromKey],
        let toNode = nodesByKey[edge.toKey]
      else {
        return nil
      }

      return "\(fromNode.id) -> \(reasonLabel(for: edge.reason)) -> \(toNode.id)"
    }

    return Set(summaries).sorted()
  }
}
