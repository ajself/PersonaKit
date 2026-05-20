import ContextWorkspaceCore
import SwiftUI

/// Reusable layered map view for session and workspace dependency visualization.
struct SessionDependencyMapView: View {
  let map: WorkspaceSessionMap
  let scopeByNodeKey: [String: WorkspaceSourceScope]
  let highlightedNodeKey: String?
  let compact: Bool
  let showsSessionLane: Bool
  let showsEmptyLanes: Bool
  let onSelectNode: (WorkspaceSessionMapNode) -> Void

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
    showsSessionLane: Bool = true,
    showsEmptyLanes: Bool = true,
    onSelectNode: @escaping (WorkspaceSessionMapNode) -> Void
  ) {
    self.map = map
    self.scopeByNodeKey = scopeByNodeKey
    self.highlightedNodeKey = highlightedNodeKey
    self.compact = compact
    self.showsSessionLane = showsSessionLane
    self.showsEmptyLanes = showsEmptyLanes
    self.onSelectNode = onSelectNode
  }

  private static let allLaneKinds: [WorkspaceSessionMapNodeKind] = [
    .session,
    .persona,
    .directive,
    .kit,
    .intent,
    .skill,
    .essential,
    .reference,
  ]

  var body: some View {
    ScrollView([.horizontal, .vertical]) {
      HStack(alignment: .top, spacing: compact ? 18 : 34) {
        ForEach(laneOrder, id: \.rawValue) { kind in
          laneView(
            kind: kind,
            nodes: nodes(for: kind)
          )
        }
      }
      .padding(compact ? 12 : 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .backgroundPreferenceValue(SessionMapNodeFramePreferenceKey.self) { anchors in
        GeometryReader { proxy in
          let nodeFrames = resolvedNodeFrames(
            anchors: anchors,
            proxy: proxy
          )

          Canvas { context, _ in
            for edge in edgeDrawOrder {
              guard let fromFrame = nodeFrames[edge.fromKey],
                let toFrame = nodeFrames[edge.toKey]
              else {
                continue
              }

              let route = SessionMapEdgeRouter.route(
                from: fromFrame,
                to: toFrame,
                avoiding:
                  nodeFrames
                  .filter { key, _ in key != edge.fromKey && key != edge.toKey }
                  .map(\.value),
                compact: compact
              )

              let color = edgeColor(edge)
              let highlighted = isHighlightedEdge(edge)
              context.stroke(
                route.path,
                with: .color(color),
                style: StrokeStyle(
                  lineWidth: highlighted ? (compact ? 1.8 : 2.4) : (compact ? 1.0 : 1.35),
                  lineCap: .round,
                  lineJoin: .round
                )
              )

              context.fill(route.arrowPath, with: .color(color))
            }
          }
          .allowsHitTesting(false)
        }
      }
    }
    .defaultScrollAnchor(.topLeading)
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
      onSelectNode(node)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
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

        if node.displayName != node.id {
          Text(node.displayName)
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }

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
      .padding(compact ? 8 : 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground(node: node))
      .overlay(
        RoundedRectangle(cornerRadius: compact ? 8 : 10)
          .strokeBorder(cardBorderColor(node: node), lineWidth: highlightedNodeKey == node.key ? 2 : 1)
      )
      .anchorPreference(key: SessionMapNodeFramePreferenceKey.self, value: .bounds) {
        [node.key: $0]
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(nodeAccessibilityLabel(node))
    .help(nodeAccessibilityLabel(node))
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

  private func isHighlightedEdge(_ edge: WorkspaceSessionMapEdge) -> Bool {
    guard let highlightedNodeKey else {
      return false
    }

    return edge.fromKey == highlightedNodeKey || edge.toKey == highlightedNodeKey
  }

  private func edgeColor(_ edge: WorkspaceSessionMapEdge) -> Color {
    guard highlightedNodeKey != nil else {
      return .secondary.opacity(compact ? 0.32 : 0.4)
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

private struct SessionMapEdgeRoute {
  let arrowPath: Path
  let path: Path
}

private enum SessionMapEdgeRouter {
  static func route(
    from sourceFrame: CGRect,
    to targetFrame: CGRect,
    avoiding obstacleFrames: [CGRect],
    compact: Bool
  ) -> SessionMapEdgeRoute {
    let clearance = compact ? 10.0 : 14.0
    let direction: CGFloat = targetFrame.midX >= sourceFrame.midX ? 1 : -1
    let start = CGPoint(
      x: direction > 0 ? sourceFrame.maxX : sourceFrame.minX,
      y: sourceFrame.midY
    )
    let end = CGPoint(
      x: direction > 0 ? targetFrame.minX : targetFrame.maxX,
      y: targetFrame.midY
    )
    let startOut = CGPoint(x: start.x + clearance * direction, y: start.y)
    let endIn = CGPoint(x: end.x - clearance * direction, y: end.y)
    let midX = (startOut.x + endIn.x) / 2
    let directPoints = normalized([
      start,
      startOut,
      CGPoint(x: midX, y: start.y),
      CGPoint(x: midX, y: end.y),
      endIn,
      end,
    ])
    let inflatedObstacles = obstacleFrames.map {
      $0.insetBy(dx: -clearance, dy: -clearance)
    }

    if isClear(points: directPoints, obstacles: inflatedObstacles) {
      return route(from: directPoints, compact: compact)
    }

    let relevantObstacles = inflatedObstacles.filter { obstacle in
      horizontalRangesOverlap(
        min(startOut.x, endIn.x)...max(startOut.x, endIn.x),
        obstacle.minX...obstacle.maxX
      )
    }
    let detourCandidates = detourYValues(
      for: relevantObstacles.isEmpty ? inflatedObstacles : relevantObstacles,
      clearance: clearance
    )

    for detourY in detourCandidates {
      let detourPoints = normalized([
        start,
        startOut,
        CGPoint(x: startOut.x, y: detourY),
        CGPoint(x: endIn.x, y: detourY),
        endIn,
        end,
      ])

      if isClear(points: detourPoints, obstacles: inflatedObstacles) {
        return route(from: detourPoints, compact: compact)
      }
    }

    return route(from: directPoints, compact: compact)
  }

  private static func route(
    from points: [CGPoint],
    compact: Bool
  ) -> SessionMapEdgeRoute {
    var path = Path()

    if let firstPoint = points.first {
      path.move(to: firstPoint)

      for point in points.dropFirst() {
        path.addLine(to: point)
      }
    }

    return SessionMapEdgeRoute(
      arrowPath: arrowPath(for: points, size: compact ? 5.0 : 6.5),
      path: path
    )
  }

  private static func arrowPath(
    for points: [CGPoint],
    size: CGFloat
  ) -> Path {
    guard let end = points.last,
      let start = points.dropLast().last(where: { distance(from: $0, to: end) > 0.1 })
    else {
      return Path()
    }

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

  private static func detourYValues(
    for obstacles: [CGRect],
    clearance: CGFloat
  ) -> [CGFloat] {
    guard !obstacles.isEmpty else {
      return []
    }

    let upperY = max(4, obstacles.map(\.minY).min() ?? 4 - clearance)
    let lowerY = (obstacles.map(\.maxY).max() ?? 0) + clearance

    return [
      upperY - clearance,
      lowerY,
    ]
  }

  private static func isClear(
    points: [CGPoint],
    obstacles: [CGRect]
  ) -> Bool {
    zip(points, points.dropFirst()).allSatisfy { start, end in
      !obstacles.contains { obstacle in
        segmentIntersects(
          start: start,
          end: end,
          rect: obstacle
        )
      }
    }
  }

  private static func segmentIntersects(
    start: CGPoint,
    end: CGPoint,
    rect: CGRect
  ) -> Bool {
    if abs(start.x - end.x) < 0.1 {
      return start.x >= rect.minX
        && start.x <= rect.maxX
        && verticalRangesOverlap(
          min(start.y, end.y)...max(start.y, end.y),
          rect.minY...rect.maxY
        )
    }

    if abs(start.y - end.y) < 0.1 {
      return start.y >= rect.minY
        && start.y <= rect.maxY
        && horizontalRangesOverlap(
          min(start.x, end.x)...max(start.x, end.x),
          rect.minX...rect.maxX
        )
    }

    return rect.contains(start) || rect.contains(end)
  }

  private static func horizontalRangesOverlap(
    _ lhs: ClosedRange<CGFloat>,
    _ rhs: ClosedRange<CGFloat>
  ) -> Bool {
    lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
  }

  private static func verticalRangesOverlap(
    _ lhs: ClosedRange<CGFloat>,
    _ rhs: ClosedRange<CGFloat>
  ) -> Bool {
    lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
  }

  private static func normalized(
    _ points: [CGPoint]
  ) -> [CGPoint] {
    points.reduce(into: []) { result, point in
      guard let lastPoint = result.last else {
        result.append(point)
        return
      }

      if distance(from: lastPoint, to: point) > 0.1 {
        result.append(point)
      }
    }
  }

  private static func distance(
    from lhs: CGPoint,
    to rhs: CGPoint
  ) -> CGFloat {
    hypot(lhs.x - rhs.x, lhs.y - rhs.y)
  }
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
    case .intent:
      return "Intents"
    case .skill:
      return "Skills"
    case .essential:
      return "Essentials"
    case .reference:
      return "References"
    }
  }
}
