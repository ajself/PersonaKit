import CoreGraphics

struct RelationshipMapLayoutState: Equatable {
  static let maximumVerticalOffset = CGFloat(320)
  static let minimumVerticalOffset = CGFloat(-160)
  static let routeMargin = CGFloat(24)

  var nodeOffsetsByKey: [String: CGSize]

  init(
    nodeOffsetsByKey: [String: CGSize] = [:]
  ) {
    self.nodeOffsetsByKey = Self.normalizedOffsets(nodeOffsetsByKey)
  }

  var hasManualOffsets: Bool {
    !nodeOffsetsByKey.isEmpty
  }

  mutating func updateOffset(
    for nodeKey: String,
    to offset: CGSize
  ) {
    let normalizedOffset = Self.normalizedOffset(offset)

    if normalizedOffset == .zero {
      nodeOffsetsByKey.removeValue(forKey: nodeKey)
    } else {
      nodeOffsetsByKey[nodeKey] = normalizedOffset
    }
  }

  mutating func pruneOffsets(
    validNodeKeys: Set<String>
  ) {
    nodeOffsetsByKey = nodeOffsetsByKey.filter { nodeKey, _ in
      validNodeKeys.contains(nodeKey)
    }
  }

  mutating func reset() {
    nodeOffsetsByKey.removeAll()
  }

  static func offset(
    baseOffset: CGSize,
    translation: CGSize
  ) -> CGSize {
    normalizedOffset(
      CGSize(
        width: 0,
        height: baseOffset.height + translation.height
      )
    )
  }

  static func contentOverflow(
    offsetsByNodeKey: [String: CGSize],
    routeMargin: CGFloat = Self.routeMargin
  ) -> RelationshipMapLayoutOverflow {
    let normalizedOffsets = normalizedOffsets(offsetsByNodeKey)
    let minimumOffset = normalizedOffsets.values.map(\.height).min() ?? 0
    let maximumOffset = normalizedOffsets.values.map(\.height).max() ?? 0
    let topOverflow =
      minimumOffset < 0
      ? abs(minimumOffset) + routeMargin
      : 0
    let bottomOverflow =
      maximumOffset > 0
      ? maximumOffset + routeMargin
      : 0

    return RelationshipMapLayoutOverflow(
      top: topOverflow,
      bottom: bottomOverflow
    )
  }

  static func visualFrame(
    _ frame: CGRect,
    by offset: CGSize
  ) -> CGRect {
    let normalizedOffset = normalizedOffset(offset)

    return frame.offsetBy(
      dx: normalizedOffset.width,
      dy: normalizedOffset.height
    )
  }

  static func visualFrames(
    _ framesByNodeKey: [String: CGRect],
    offsetsByNodeKey: [String: CGSize]
  ) -> [String: CGRect] {
    Dictionary(
      uniqueKeysWithValues: framesByNodeKey.map { nodeKey, frame in
        (
          nodeKey,
          visualFrame(
            frame,
            by: offsetsByNodeKey[nodeKey] ?? .zero
          )
        )
      }
    )
  }

  private static func normalizedOffsets(
    _ offsets: [String: CGSize]
  ) -> [String: CGSize] {
    offsets.reduce(into: [:]) { result, entry in
      let normalizedOffset = normalizedOffset(entry.value)

      if normalizedOffset != .zero {
        result[entry.key] = normalizedOffset
      }
    }
  }

  private static func normalizedOffset(
    _ offset: CGSize
  ) -> CGSize {
    CGSize(
      width: 0,
      height: normalizedComponent(
        min(
          maximumVerticalOffset,
          max(
            minimumVerticalOffset,
            offset.height
          )
        )
      )
    )
  }

  private static func normalizedComponent(
    _ value: CGFloat
  ) -> CGFloat {
    abs(value) < 0.5 ? 0 : value
  }
}

struct RelationshipMapLayoutOverflow: Equatable {
  let top: CGFloat
  let bottom: CGFloat

  static let zero = RelationshipMapLayoutOverflow(
    top: 0,
    bottom: 0
  )
}

enum RelationshipMapDragState {
  static let minimumDragDistance = CGFloat(6)

  static func shouldBeginDrag(
    translation: CGSize
  ) -> Bool {
    hypot(translation.width, translation.height) >= minimumDragDistance
  }
}

struct RelationshipMapDragInteractionState: Equatable {
  private(set) var activeNodeKey: String?
  private var startOffsetByNodeKey: [String: CGSize] = [:]
  private var suppressedSelectionNodeKeys: Set<String> = []

  mutating func updatedOffset(
    for nodeKey: String,
    currentOffset: CGSize,
    translation: CGSize
  ) -> CGSize? {
    guard RelationshipMapDragState.shouldBeginDrag(translation: translation) else {
      return nil
    }

    if activeNodeKey != nodeKey {
      activeNodeKey = nodeKey
      startOffsetByNodeKey[nodeKey] = currentOffset
    }

    return RelationshipMapLayoutState.offset(
      baseOffset: startOffsetByNodeKey[nodeKey] ?? .zero,
      translation: translation
    )
  }

  mutating func endedOffset(
    for nodeKey: String,
    currentOffset: CGSize,
    translation: CGSize
  ) -> CGSize? {
    defer {
      activeNodeKey = nil
      startOffsetByNodeKey.removeValue(forKey: nodeKey)
    }

    guard RelationshipMapDragState.shouldBeginDrag(translation: translation) || activeNodeKey == nodeKey else {
      return nil
    }

    suppressedSelectionNodeKeys.insert(nodeKey)

    return RelationshipMapLayoutState.offset(
      baseOffset: startOffsetByNodeKey[nodeKey] ?? currentOffset,
      translation: translation
    )
  }

  mutating func shouldSuppressSelection(
    for nodeKey: String
  ) -> Bool {
    suppressedSelectionNodeKeys.remove(nodeKey) != nil
  }
}
