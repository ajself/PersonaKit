import ContextWorkspaceCore
import SwiftUI

/// Reusable layered map view for session and workspace dependency visualization.
struct SessionDependencyMapView: View {
  let map: WorkspaceSessionMap
  let scopeByNodeKey: [String: WorkspaceSourceScope]
  let highlightedNodeKey: String?
  let compact: Bool
  let onSelectNode: (WorkspaceSessionMapNode) -> Void

  private let laneOrder: [WorkspaceSessionMapNodeKind] = [
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
      HStack(alignment: .top, spacing: compact ? 14 : 20) {
        ForEach(laneOrder, id: \.rawValue) { kind in
          laneView(
            kind: kind,
            nodes: nodes(for: kind)
          )
        }
      }
      .padding(compact ? 10 : 14)
      .overlayPreferenceValue(SessionMapNodeAnchorPreferenceKey.self) { anchors in
        GeometryReader { proxy in
          Canvas { context, _ in
            for edge in map.edges {
              guard let fromAnchor = anchors[edge.fromKey],
                let toAnchor = anchors[edge.toKey]
              else {
                continue
              }

              let fromPoint = proxy[fromAnchor]
              let toPoint = proxy[toAnchor]
              let controlX = (fromPoint.x + toPoint.x) / 2

              var path = Path()
              path.move(to: fromPoint)
              path.addCurve(
                to: toPoint,
                control1: CGPoint(x: controlX, y: fromPoint.y),
                control2: CGPoint(x: controlX, y: toPoint.y)
              )

              context.stroke(
                path,
                with: .color(.secondary.opacity(compact ? 0.28 : 0.34)),
                lineWidth: compact ? 1.0 : 1.4
              )
            }
          }
          .allowsHitTesting(false)
        }
      }
    }
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
      .anchorPreference(key: SessionMapNodeAnchorPreferenceKey.self, value: .center) {
        [node.key: $0]
      }
    }
    .buttonStyle(.plain)
  }

  private func nodes(for kind: WorkspaceSessionMapNodeKind) -> [WorkspaceSessionMapNode] {
    map.nodes.filter { $0.kind == kind }
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

  private func cardBackground(node: WorkspaceSessionMapNode) -> some View {
    RoundedRectangle(cornerRadius: compact ? 8 : 10)
      .fill(node.isMissing ? Color.red.opacity(0.08) : Color.secondary.opacity(0.08))
  }

  private func cardBorderColor(node: WorkspaceSessionMapNode) -> Color {
    if highlightedNodeKey == node.key {
      return .blue
    }

    if node.isMissing {
      return .red.opacity(0.55)
    }

    return .secondary.opacity(0.3)
  }
}

private struct SessionMapNodeAnchorPreferenceKey: PreferenceKey {
  static let defaultValue: [String: Anchor<CGPoint>] = [:]

  static func reduce(
    value: inout [String: Anchor<CGPoint>],
    nextValue: () -> [String: Anchor<CGPoint>]
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
