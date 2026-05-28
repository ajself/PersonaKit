struct WorkspaceSessionMapMutableNode {
  let key: String
  let id: String
  var displayName: String
  let kind: WorkspaceSessionMapNodeKind
  var isMissing: Bool
  var badges: Set<String>
}

struct WorkspaceSessionMapEdgeKey: Hashable {
  let fromKey: String
  let toKey: String
  let reason: String
}

func workspaceSessionMapNodeKey(
  kind: WorkspaceSessionMapNodeKind,
  id: String
) -> String {
  "\(kind.rawValue):\(id)"
}

func upsertWorkspaceSessionMapNode(
  in nodeStateByKey: inout [String: WorkspaceSessionMapMutableNode],
  kind: WorkspaceSessionMapNodeKind,
  id: String,
  displayName: String,
  isMissing: Bool,
  badge: String? = nil
) {
  let key = workspaceSessionMapNodeKey(kind: kind, id: id)

  if var existing = nodeStateByKey[key] {
    existing.isMissing = existing.isMissing || isMissing

    if existing.displayName == existing.id,
      displayName != id
    {
      existing.displayName = displayName
    }

    if let badge {
      existing.badges.insert(badge)
    }

    nodeStateByKey[key] = existing
    return
  }

  var badges: Set<String> = []

  if let badge {
    badges.insert(badge)
  }

  nodeStateByKey[key] = WorkspaceSessionMapMutableNode(
    key: key,
    id: id,
    displayName: displayName,
    kind: kind,
    isMissing: isMissing,
    badges: badges
  )
}

func sortedWorkspaceSessionMapNodes(
  from nodeStateByKey: [String: WorkspaceSessionMapMutableNode]
) -> [WorkspaceSessionMapNode] {
  nodeStateByKey.values
    .map {
      WorkspaceSessionMapNode(
        key: $0.key,
        id: $0.id,
        displayName: $0.displayName,
        kind: $0.kind,
        isMissing: $0.isMissing,
        badges: $0.badges.sorted()
      )
    }
    .sorted { lhs, rhs in
      if lhs.kind.sortOrder != rhs.kind.sortOrder {
        return lhs.kind.sortOrder < rhs.kind.sortOrder
      }

      if lhs.id != rhs.id {
        return lhs.id < rhs.id
      }

      return lhs.key < rhs.key
    }
}

func sortedWorkspaceSessionMapEdges(
  from edgeKeys: Set<WorkspaceSessionMapEdgeKey>,
  nodes: [WorkspaceSessionMapNode]
) -> [WorkspaceSessionMapEdge] {
  let nodeByKey = Dictionary(uniqueKeysWithValues: nodes.map { ($0.key, $0) })

  return
    edgeKeys
    .map {
      WorkspaceSessionMapEdge(
        fromKey: $0.fromKey,
        toKey: $0.toKey,
        reason: $0.reason
      )
    }
    .sorted { lhs, rhs in
      let lhsFrom = nodeByKey[lhs.fromKey]
      let rhsFrom = nodeByKey[rhs.fromKey]

      if lhsFrom?.kind.sortOrder != rhsFrom?.kind.sortOrder {
        return (lhsFrom?.kind.sortOrder ?? Int.max) < (rhsFrom?.kind.sortOrder ?? Int.max)
      }

      if lhsFrom?.id != rhsFrom?.id {
        return (lhsFrom?.id ?? lhs.fromKey) < (rhsFrom?.id ?? rhs.fromKey)
      }

      let lhsTo = nodeByKey[lhs.toKey]
      let rhsTo = nodeByKey[rhs.toKey]

      if lhsTo?.kind.sortOrder != rhsTo?.kind.sortOrder {
        return (lhsTo?.kind.sortOrder ?? Int.max) < (rhsTo?.kind.sortOrder ?? Int.max)
      }

      if lhsTo?.id != rhsTo?.id {
        return (lhsTo?.id ?? lhs.toKey) < (rhsTo?.id ?? rhs.toKey)
      }

      return lhs.reason < rhs.reason
    }
}

func sortedUniqueWorkspaceSessionMapValues(_ values: [String]) -> [String] {
  Set(values).sorted()
}
