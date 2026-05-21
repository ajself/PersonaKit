import ContextWorkspaceCore
import CoreGraphics
import Foundation

struct RelationshipMapRouteRecord: Equatable, Sendable {
  let edgeIdentity: String
  let fromKey: String
  let toKey: String
  let reason: String
  let sourceFrame: CGRect
  let targetFrame: CGRect
  let startPoint: CGPoint
  let endPoint: CGPoint
  let points: [CGPoint]

  var edge: WorkspaceSessionMapEdge {
    WorkspaceSessionMapEdge(
      fromKey: fromKey,
      toKey: toKey,
      reason: reason
    )
  }
}

enum RelationshipMapRouteGeometry {
  static func routeRecords(
    edges: [WorkspaceSessionMapEdge],
    baselineNodeFrames: [String: CGRect],
    offsetsByNodeKey: [String: CGSize],
    compact: Bool
  ) -> [RelationshipMapRouteRecord] {
    let visualNodeFrames = RelationshipMapLayoutState.visualFrames(
      baselineNodeFrames,
      offsetsByNodeKey: offsetsByNodeKey
    )

    return edges.compactMap { edge in
      guard let sourceFrame = visualNodeFrames[edge.fromKey],
        let targetFrame = visualNodeFrames[edge.toKey]
      else {
        return nil
      }

      let obstacleFrames =
        visualNodeFrames
        .filter { key, _ in key != edge.fromKey && key != edge.toKey }
        .map(\.value)
      let points = routePoints(
        from: sourceFrame,
        to: targetFrame,
        avoiding: obstacleFrames,
        compact: compact
      )

      guard let startPoint = points.first,
        let endPoint = points.last
      else {
        return nil
      }

      return RelationshipMapRouteRecord(
        edgeIdentity: edge.relationshipMapIdentity,
        fromKey: edge.fromKey,
        toKey: edge.toKey,
        reason: edge.reason,
        sourceFrame: sourceFrame,
        targetFrame: targetFrame,
        startPoint: startPoint,
        endPoint: endPoint,
        points: points
      )
    }
  }

  private static func routePoints(
    from sourceFrame: CGRect,
    to targetFrame: CGRect,
    avoiding obstacleFrames: [CGRect],
    compact: Bool
  ) -> [CGPoint] {
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
      return directPoints
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
        return detourPoints
      }
    }

    return directPoints
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

enum RelationshipMapRouteGeometryExport {
  static func signature(
    for routes: [RelationshipMapRouteRecord]
  ) -> String {
    routes.map { route in
      [
        route.edgeIdentity,
        format(route.startPoint.x),
        format(route.startPoint.y),
        format(route.endPoint.x),
        format(route.endPoint.y),
      ]
      .joined(separator: ":")
    }
    .joined(separator: "|")
  }

  static func write(
    routes: [RelationshipMapRouteRecord],
    to fileURL: URL
  ) throws {
    let snapshot = RelationshipMapRouteGeometrySnapshot(
      routes: routes.map(RelationshipMapRouteGeometrySnapshot.Route.init)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
    ]

    let data = try encoder.encode(snapshot)
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    try data.write(to: fileURL, options: [.atomic])
  }

  private static func format(_ value: CGFloat) -> String {
    String(format: "%.2f", Double(value))
  }
}

private struct RelationshipMapRouteGeometrySnapshot: Encodable {
  let routes: [Route]

  struct Route: Encodable {
    let edgeIdentity: String
    let endPoint: Point
    let fromKey: String
    let points: [Point]
    let reason: String
    let sourceFrame: Rect
    let startPoint: Point
    let targetFrame: Rect
    let toKey: String

    init(_ record: RelationshipMapRouteRecord) {
      edgeIdentity = record.edgeIdentity
      endPoint = Point(record.endPoint)
      fromKey = record.fromKey
      points = record.points.map(Point.init)
      reason = record.reason
      sourceFrame = Rect(record.sourceFrame)
      startPoint = Point(record.startPoint)
      targetFrame = Rect(record.targetFrame)
      toKey = record.toKey
    }
  }

  struct Point: Encodable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
      x = Double(point.x)
      y = Double(point.y)
    }
  }

  struct Rect: Encodable {
    let height: Double
    let maxX: Double
    let maxY: Double
    let midX: Double
    let midY: Double
    let minX: Double
    let minY: Double
    let width: Double

    init(_ rect: CGRect) {
      height = Double(rect.height)
      maxX = Double(rect.maxX)
      maxY = Double(rect.maxY)
      midX = Double(rect.midX)
      midY = Double(rect.midY)
      minX = Double(rect.minX)
      minY = Double(rect.minY)
      width = Double(rect.width)
    }
  }
}

extension WorkspaceSessionMapEdge {
  var relationshipMapIdentity: String {
    "\(fromKey)->\(toKey)::\(reason)"
  }
}
