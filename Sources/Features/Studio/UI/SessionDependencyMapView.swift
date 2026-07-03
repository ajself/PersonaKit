import ContextWorkspaceCore
import SwiftUI

/// Reusable layered map view for session and workspace dependency visualization.
struct SessionDependencyMapView: View {
  let map: WorkspaceSessionMap
  let scopeByNodeKey: [String: WorkspaceSourceScope]
  let highlightedNodeKey: String?
  let compact: Bool
  let allowsNodeDragging: Bool
  let showsSessionLane: Bool
  let showsEmptyLanes: Bool
  let onSelectNode: (WorkspaceSessionMapNode) -> Void

  @Binding private var nodeOffsetsByKey: [String: CGSize]
  @State private var dragInteractionState = RelationshipMapDragInteractionState()

  private var laneOrder: [WorkspaceSessionMapNodeKind] {
    let allKinds =
      showsSessionLane
      ? Self.allLaneKinds
      : Self.allLaneKinds.filter { $0 != .session }

    return RelationshipMapPresentationState.visibleLaneKinds(
      map: map,
      laneOrder: allKinds,
      showsEmptyLanes: showsEmptyLanes
    )
  }

  init(
    map: WorkspaceSessionMap,
    scopeByNodeKey: [String: WorkspaceSourceScope],
    highlightedNodeKey: String?,
    compact: Bool,
    allowsNodeDragging: Bool = false,
    nodeOffsetsByKey: Binding<[String: CGSize]> = .constant([:]),
    showsSessionLane: Bool = true,
    showsEmptyLanes: Bool = true,
    onSelectNode: @escaping (WorkspaceSessionMapNode) -> Void
  ) {
    self.map = map
    self.scopeByNodeKey = scopeByNodeKey
    self.highlightedNodeKey = highlightedNodeKey
    self.compact = compact
    self.allowsNodeDragging = allowsNodeDragging
    self.showsSessionLane = showsSessionLane
    self.showsEmptyLanes = showsEmptyLanes
    self.onSelectNode = onSelectNode
    _nodeOffsetsByKey = nodeOffsetsByKey
  }

  private static let allLaneKinds: [WorkspaceSessionMapNodeKind] = [
    .session,
    .persona,
    .directive,
    .kit,
    .skill,
  ]

  var body: some View {
    let contentPadding = compact ? CGFloat(12) : CGFloat(18)
    let layoutOverflow = contentOverflow

    ScrollView([.horizontal, .vertical]) {
      HStack(alignment: .top, spacing: compact ? 18 : 34) {
        ForEach(laneOrder, id: \.rawValue) { kind in
          laneView(
            kind: kind,
            nodes: nodes(for: kind)
          )
        }
      }
      .padding(.horizontal, contentPadding)
      .padding(.top, contentPadding + layoutOverflow.top)
      .padding(.bottom, contentPadding + layoutOverflow.bottom)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .backgroundPreferenceValue(SessionMapNodeFramePreferenceKey.self) { anchors in
        GeometryReader { proxy in
          let baselineNodeFrames = resolvedNodeFrames(
            anchors: anchors,
            proxy: proxy
          )
          let routes = relationshipMapRoutes(
            baselineNodeFrames: baselineNodeFrames
          )

          ZStack {
            Canvas { context, _ in
              for route in routes {
                let edge = route.edge
                let color = edgeColor(edge)
                let highlighted = isHighlightedEdge(edge)
                context.stroke(
                  path(for: route.points),
                  with: .color(color),
                  style: StrokeStyle(
                    lineWidth: highlighted ? (compact ? 1.8 : 2.4) : (compact ? 1.15 : 1.55),
                    lineCap: .round,
                    lineJoin: .round
                  )
                )

                context.fill(
                  arrowPath(
                    for: route.points,
                    compact: compact
                  ),
                  with: .color(color)
                )
              }
            }
            .allowsHitTesting(false)

            relationshipMapGeometryExportView(routes: routes)
          }
        }
      }
    }
    .defaultScrollAnchor(.topLeading)
    .accessibilityIdentifier(RelationshipMapAutomationIdentifier.mapCanvas)
  }

  private var contentOverflow: RelationshipMapLayoutOverflow {
    guard allowsNodeDragging else {
      return .zero
    }

    return RelationshipMapLayoutState.contentOverflow(
      offsetsByNodeKey: nodeOffsetsByKey
    )
  }

  private func laneView(
    kind: WorkspaceSessionMapNodeKind,
    nodes: [WorkspaceSessionMapNode]
  ) -> some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 10) {
      Text(kind.title)
        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      if nodes.isEmpty {
        Text("No nodes")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(minWidth: compact ? 130 : 170, alignment: .leading)
      } else {
        ForEach(nodes, id: \.key) { node in
          nodeCard(node)
        }
      }
    }
    .frame(minWidth: compact ? 150 : 190, alignment: .topLeading)
  }

  private func nodeCard(_ node: WorkspaceSessionMapNode) -> some View {
    Button {
      if dragInteractionState.shouldSuppressSelection(for: node.key) {
        return
      }

      onSelectNode(node)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        nodeCardHeader(node)
        nodeCardSubtitle(node)
        nodeCardBadges(node)
      }
      .padding(compact ? 8 : 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground(node: node))
      .overlay(
        RoundedRectangle(cornerRadius: compact ? 8 : 10)
          .strokeBorder(cardBorderColor(node: node), lineWidth: highlightedNodeKey == node.key ? 2 : 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: compact ? 8 : 10))
    }
    .buttonStyle(.plain)
    .offset(offset(for: node.key))
    .anchorPreference(key: SessionMapNodeFramePreferenceKey.self, value: .bounds) {
      [node.key: $0]
    }
    .zIndex(dragInteractionState.activeNodeKey == node.key ? 1 : 0)
    .simultaneousGesture(nodeDragGesture(for: node.key))
    .accessibilityLabel(nodeAccessibilityLabel(node))
    .accessibilityIdentifier(RelationshipMapAutomationIdentifier.node(key: node.key))
    .help(nodeAccessibilityLabel(node))
  }

  private func nodeCardHeader(_ node: WorkspaceSessionMapNode) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(node.id)
        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .multilineTextAlignment(.leading)
        .foregroundStyle(node.isMissing ? .red : .primary)

      Spacer(minLength: 0)

      if let scope = scopeByNodeKey[node.key] {
        scopeBadge(scope)
      }
    }
  }

  @ViewBuilder
  private func nodeCardSubtitle(_ node: WorkspaceSessionMapNode) -> some View {
    if node.displayName != node.id {
      Text(node.displayName)
        .font(compact ? .caption2 : .caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
    }
  }

  @ViewBuilder
  private func nodeCardBadges(_ node: WorkspaceSessionMapNode) -> some View {
    if !node.badges.isEmpty {
      HStack(spacing: 6) {
        ForEach(node.badges.sorted(), id: \.self) { badge in
          Text(badge)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              Capsule()
                .fill(.orange.opacity(0.18))
            )
            .foregroundStyle(.orange)
        }
      }
    }
  }

  private func nodes(for kind: WorkspaceSessionMapNodeKind) -> [WorkspaceSessionMapNode] {
    map.nodes.filter { $0.kind == kind }
  }

  private var edgeDrawOrder: [WorkspaceSessionMapEdge] {
    map.edges.sorted { lhs, rhs in
      let lhsHighlighted = isHighlightedEdge(lhs)
      let rhsHighlighted = isHighlightedEdge(rhs)

      if lhsHighlighted != rhsHighlighted {
        return !lhsHighlighted && rhsHighlighted
      }

      if lhs.fromKey != rhs.fromKey {
        return lhs.fromKey < rhs.fromKey
      }

      if lhs.toKey != rhs.toKey {
        return lhs.toKey < rhs.toKey
      }

      return lhs.reason < rhs.reason
    }
  }

  private func resolvedNodeFrames(
    anchors: [String: Anchor<CGRect>],
    proxy: GeometryProxy
  ) -> [String: CGRect] {
    Dictionary(
      uniqueKeysWithValues: anchors.map { key, anchor in
        (key, proxy[anchor])
      }
    )
  }

  private func offset(
    for nodeKey: String
  ) -> CGSize {
    guard allowsNodeDragging else {
      return .zero
    }

    return nodeOffsetsByKey[nodeKey] ?? .zero
  }

  private func nodeDragGesture(
    for nodeKey: String
  ) -> some Gesture {
    DragGesture(
      minimumDistance:
        allowsNodeDragging
        ? 0
        : .infinity
    )
    .onChanged { value in
      guard allowsNodeDragging else {
        return
      }

      guard
        let updatedOffset = dragInteractionState.updatedOffset(
          for: nodeKey,
          currentOffset: nodeOffsetsByKey[nodeKey] ?? .zero,
          translation: value.translation
        )
      else {
        return
      }

      nodeOffsetsByKey[nodeKey] = updatedOffset
    }
    .onEnded { value in
      guard allowsNodeDragging else {
        return
      }

      guard
        let finalOffset = dragInteractionState.endedOffset(
          for: nodeKey,
          currentOffset: nodeOffsetsByKey[nodeKey] ?? .zero,
          translation: value.translation
        )
      else {
        return
      }

      if finalOffset == .zero {
        nodeOffsetsByKey.removeValue(forKey: nodeKey)
      } else {
        nodeOffsetsByKey[nodeKey] = finalOffset
      }
    }
  }

  private func relationshipMapRoutes(
    baselineNodeFrames: [String: CGRect]
  ) -> [RelationshipMapRouteRecord] {
    RelationshipMapRouteGeometry.routeRecords(
      edges: edgeDrawOrder,
      baselineNodeFrames: baselineNodeFrames,
      offsetsByNodeKey: allowsNodeDragging ? nodeOffsetsByKey : [:],
      compact: compact
    )
  }

  @ViewBuilder
  private func relationshipMapGeometryExportView(
    routes: [RelationshipMapRouteRecord]
  ) -> some View {
    if let fileURL = StudioLaunchConfiguration.relationshipMapGeometryFileURL() {
      Color.clear
        .task(id: RelationshipMapRouteGeometryExport.signature(for: routes)) {
          try? RelationshipMapRouteGeometryExport.write(
            routes: routes,
            to: fileURL
          )
        }
    }
  }

  private func isHighlightedEdge(_ edge: WorkspaceSessionMapEdge) -> Bool {
    guard let highlightedNodeKey else {
      return false
    }

    return edge.fromKey == highlightedNodeKey || edge.toKey == highlightedNodeKey
  }

  private func edgeColor(_ edge: WorkspaceSessionMapEdge) -> Color {
    guard highlightedNodeKey != nil else {
      return .secondary.opacity(compact ? 0.4 : 0.5)
    }

    if isHighlightedEdge(edge) {
      return .blue.opacity(0.72)
    }

    return .secondary.opacity(compact ? 0.14 : 0.18)
  }

  private func isNodeConnectedToHighlight(_ node: WorkspaceSessionMapNode) -> Bool {
    guard let highlightedNodeKey, highlightedNodeKey != node.key else {
      return false
    }

    return map.edges.contains { edge in
      (edge.fromKey == highlightedNodeKey && edge.toKey == node.key)
        || (edge.toKey == highlightedNodeKey && edge.fromKey == node.key)
    }
  }

  private func scopeBadge(_ scope: WorkspaceSourceScope) -> some View {
    Text(scope.displayName)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(scope == .project ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
  }

  private func nodeAccessibilityLabel(_ node: WorkspaceSessionMapNode) -> String {
    var parts = [
      node.kind.title,
      node.id,
    ]

    if node.displayName != node.id {
      parts.append(node.displayName)
    }

    if let scope = scopeByNodeKey[node.key] {
      parts.append(scope.displayName)
    }

    if !node.badges.isEmpty {
      parts.append(node.badges.sorted().joined(separator: ", "))
    }

    return parts.joined(separator: ", ")
  }

  private func cardBackground(node: WorkspaceSessionMapNode) -> some View {
    RoundedRectangle(cornerRadius: compact ? 8 : 10)
      .fill(.background)
      .overlay {
        RoundedRectangle(cornerRadius: compact ? 8 : 10)
          .fill(cardTintColor(node: node))
      }
  }

  private func cardBorderColor(node: WorkspaceSessionMapNode) -> Color {
    if highlightedNodeKey == node.key {
      return .blue
    }

    if isNodeConnectedToHighlight(node) {
      return .blue.opacity(0.48)
    }

    if node.isMissing {
      return .red.opacity(0.55)
    }

    return .secondary.opacity(0.3)
  }

  private func cardTintColor(node: WorkspaceSessionMapNode) -> Color {
    if node.isMissing {
      return .red.opacity(0.08)
    }

    if highlightedNodeKey == node.key || isNodeConnectedToHighlight(node) {
      return .blue.opacity(0.07)
    }

    return .secondary.opacity(0.08)
  }
}

private func path(
  for points: [CGPoint]
) -> Path {
  var path = Path()

  if let firstPoint = points.first {
    path.move(to: firstPoint)

    for point in points.dropFirst() {
      path.addLine(to: point)
    }
  }

  return path
}

private func arrowPath(
  for points: [CGPoint],
  compact: Bool
) -> Path {
  guard let end = points.last,
    let start = points.dropLast().last(where: { distance(from: $0, to: end) > 0.1 })
  else {
    return Path()
  }

  let size = compact ? CGFloat(5.0) : CGFloat(6.5)
  let angle = atan2(end.y - start.y, end.x - start.x)
  let sideAngle = CGFloat.pi / 7
  let firstWing = CGPoint(
    x: end.x - size * cos(angle - sideAngle),
    y: end.y - size * sin(angle - sideAngle)
  )
  let secondWing = CGPoint(
    x: end.x - size * cos(angle + sideAngle),
    y: end.y - size * sin(angle + sideAngle)
  )

  var path = Path()
  path.move(to: end)
  path.addLine(to: firstWing)
  path.addLine(to: secondWing)
  path.closeSubpath()

  return path
}

private func distance(
  from lhs: CGPoint,
  to rhs: CGPoint
) -> CGFloat {
  hypot(lhs.x - rhs.x, lhs.y - rhs.y)
}

private struct SessionMapNodeFramePreferenceKey: PreferenceKey {
  static let defaultValue: [String: Anchor<CGRect>] = [:]

  static func reduce(
    value: inout [String: Anchor<CGRect>],
    nextValue: () -> [String: Anchor<CGRect>]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, rhs in rhs })
  }
}

extension WorkspaceSessionMapNodeKind {
  fileprivate var title: String {
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
