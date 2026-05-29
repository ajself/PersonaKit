import ContextWorkspaceCore
import CoreGraphics
import Testing

@testable import StudioFeatures

struct StudioRelationshipMapPresentationStateTests {
  @Test
  func visibleLaneKindsHideEmptyLanesWhenRequested() {
    let map = WorkspaceSessionMap(
      nodes: [
        WorkspaceSessionMapNode(
          key: "persona:solo-developer",
          id: "solo-developer",
          displayName: "Solo Developer",
          kind: .persona,
          isMissing: false,
          badges: []
        ),
        WorkspaceSessionMapNode(
          key: "kit:cli-guardrails",
          id: "cli-guardrails",
          displayName: "CLI Guardrails",
          kind: .kit,
          isMissing: false,
          badges: []
        ),
      ],
      edges: [],
      resolutionErrors: [],
      isFullyResolved: true
    )

    let visibleKinds = RelationshipMapPresentationState.visibleLaneKinds(
      map: map,
      laneOrder: [.session, .persona, .directive, .kit, .intent],
      showsEmptyLanes: false
    )

    #expect(visibleKinds == [.persona, .kit])
  }

  @Test
  func relationshipSummariesUseReadableReasonLabels() {
    let map = WorkspaceSessionMap(
      nodes: [
        WorkspaceSessionMapNode(
          key: "persona:solo-developer",
          id: "solo-developer",
          displayName: "Solo Developer",
          kind: .persona,
          isMissing: false,
          badges: []
        ),
        WorkspaceSessionMapNode(
          key: "kit:cli-guardrails",
          id: "cli-guardrails",
          displayName: "CLI Guardrails",
          kind: .kit,
          isMissing: false,
          badges: []
        ),
      ],
      edges: [
        WorkspaceSessionMapEdge(
          fromKey: "persona:solo-developer",
          toKey: "kit:cli-guardrails",
          reason: "persona.defaultKitIds"
        ),
        WorkspaceSessionMapEdge(
          fromKey: "persona:solo-developer",
          toKey: "kit:cli-guardrails",
          reason: "persona.defaultKitIds"
        ),
      ],
      resolutionErrors: [],
      isFullyResolved: true
    )

    #expect(
      RelationshipMapPresentationState.relationshipSummaries(map: map) == [
        "solo-developer -> default kit -> cli-guardrails"
      ]
    )
  }

  @Test
  func layoutStateTracksManualOffsets() {
    var layoutState = RelationshipMapLayoutState()

    #expect(!layoutState.hasManualOffsets)

    layoutState.updateOffset(
      for: "persona:solo-developer",
      to: CGSize(
        width: 24,
        height: -12
      )
    )

    #expect(layoutState.hasManualOffsets)
    #expect(
      layoutState.nodeOffsetsByKey["persona:solo-developer"]
        == CGSize(
          width: 0,
          height: -12
        )
    )

    layoutState.reset()

    #expect(!layoutState.hasManualOffsets)
    #expect(layoutState.nodeOffsetsByKey.isEmpty)
  }

  @Test
  func layoutStatePrunesOffsetsForHiddenNodes() {
    var layoutState = RelationshipMapLayoutState(
      nodeOffsetsByKey: [
        "kit:cli-guardrails": CGSize(
          width: 10,
          height: 20
        ),
        "persona:solo-developer": CGSize(
          width: -4,
          height: 8
        ),
      ]
    )

    layoutState.pruneOffsets(
      validNodeKeys: ["persona:solo-developer"]
    )

    #expect(
      layoutState.nodeOffsetsByKey == [
        "persona:solo-developer": CGSize(
          width: 0,
          height: 8
        )
      ]
    )
  }

  @Test
  func layoutStateCombinesBaseOffsetAndVerticalDragTranslation() {
    let offset = RelationshipMapLayoutState.offset(
      baseOffset: CGSize(
        width: 10,
        height: 4
      ),
      translation: CGSize(
        width: -3,
        height: 9
      )
    )

    #expect(
      offset
        == CGSize(
          width: 0,
          height: 13
        )
    )
  }

  @Test
  func layoutStateDropsTinyVerticalOffsets() {
    var layoutState = RelationshipMapLayoutState()

    layoutState.updateOffset(
      for: "persona:solo-developer",
      to: CGSize(
        width: 30,
        height: 0.25
      )
    )

    #expect(layoutState.nodeOffsetsByKey.isEmpty)
  }

  @Test
  func layoutStateClampsVerticalOffsets() {
    let downwardOffset = RelationshipMapLayoutState.offset(
      baseOffset: .zero,
      translation: CGSize(
        width: 0,
        height: 500
      )
    )
    let upwardOffset = RelationshipMapLayoutState.offset(
      baseOffset: .zero,
      translation: CGSize(
        width: 0,
        height: -500
      )
    )

    #expect(downwardOffset.height == RelationshipMapLayoutState.maximumVerticalOffset)
    #expect(upwardOffset.height == RelationshipMapLayoutState.minimumVerticalOffset)
  }

  @Test
  func layoutStateHasNoContentOverflowWithoutManualOffsets() {
    #expect(
      RelationshipMapLayoutState.contentOverflow(
        offsetsByNodeKey: [:]
      ) == .zero
    )
  }

  @Test
  func layoutStateContentOverflowIncludesPositiveOffsets() {
    let overflow = RelationshipMapLayoutState.contentOverflow(
      offsetsByNodeKey: [
        "persona:solo-developer": CGSize(
          width: 0,
          height: 80
        )
      ],
      routeMargin: 24
    )

    #expect(overflow.top == 0)
    #expect(overflow.bottom == 104)
  }

  @Test
  func layoutStateContentOverflowIncludesNegativeOffsets() {
    let overflow = RelationshipMapLayoutState.contentOverflow(
      offsetsByNodeKey: [
        "directive:small-cli-change": CGSize(
          width: 0,
          height: -60
        )
      ],
      routeMargin: 24
    )

    #expect(overflow.top == 84)
    #expect(overflow.bottom == 0)
  }

  @Test
  func layoutStateComputesVisualFrameForOffsetNode() {
    let baselineFrame = CGRect(
      x: 40,
      y: 80,
      width: 160,
      height: 44
    )

    let visualFrame = RelationshipMapLayoutState.visualFrame(
      baselineFrame,
      by: CGSize(
        width: 30,
        height: 26
      )
    )

    #expect(visualFrame.minX == baselineFrame.minX)
    #expect(visualFrame.midY == baselineFrame.midY + 26)
  }

  @Test
  func layoutStateComputesVisualFramesOnlyForOffsetNodes() {
    let directiveFrame = CGRect(
      x: 300,
      y: 120,
      width: 190,
      height: 64
    )
    let personaFrame = CGRect(
      x: 110,
      y: 200,
      width: 170,
      height: 64
    )

    let visualFrames = RelationshipMapLayoutState.visualFrames(
      [
        "directive:opencode-cli": directiveFrame,
        "persona:solo-developer": personaFrame,
      ],
      offsetsByNodeKey: [
        "directive:opencode-cli": CGSize(
          width: 0,
          height: -40
        )
      ]
    )

    #expect(visualFrames["directive:opencode-cli"]?.midY == directiveFrame.midY - 40)
    #expect(visualFrames["persona:solo-developer"] == personaFrame)
  }

  @Test
  func routeGeometryAttachesDraggedPersonaEdgesToVisualMidpoints() throws {
    let frames = relationshipRouteFrames()
    let routes = RelationshipMapRouteGeometry.routeRecords(
      edges: [
        WorkspaceSessionMapEdge(
          fromKey: "session:solo-dev",
          toKey: "persona:solo-developer",
          reason: "session.personaId"
        ),
        WorkspaceSessionMapEdge(
          fromKey: "persona:solo-developer",
          toKey: "kit:cli-guardrails",
          reason: "persona.defaultKitIds"
        ),
      ],
      baselineNodeFrames: frames,
      offsetsByNodeKey: [
        "persona:solo-developer": CGSize(
          width: 0,
          height: 120
        )
      ],
      compact: false
    )

    let visualPersonaFrame = try #require(
      RelationshipMapLayoutState.visualFrames(
        frames,
        offsetsByNodeKey: [
          "persona:solo-developer": CGSize(
            width: 0,
            height: 120
          )
        ]
      )["persona:solo-developer"]
    )
    let incomingRoute = try #require(
      routes.first { $0.toKey == "persona:solo-developer" }
    )
    let outgoingRoute = try #require(
      routes.first { $0.fromKey == "persona:solo-developer" }
    )

    #expect(incomingRoute.endPoint.x == visualPersonaFrame.minX)
    #expect(incomingRoute.endPoint.y == visualPersonaFrame.midY)
    #expect(outgoingRoute.startPoint.x == visualPersonaFrame.maxX)
    #expect(outgoingRoute.startPoint.y == visualPersonaFrame.midY)
  }

  @Test
  func routeGeometryAttachesDraggedDirectiveEdgesToVisualMidpoints() throws {
    let frames = relationshipRouteFrames()
    let routes = RelationshipMapRouteGeometry.routeRecords(
      edges: [
        WorkspaceSessionMapEdge(
          fromKey: "session:solo-dev",
          toKey: "directive:small-cli-change",
          reason: "session.directiveId"
        ),
        WorkspaceSessionMapEdge(
          fromKey: "directive:small-cli-change",
          toKey: "skill:opencode-cli",
          reason: "directive.requiredSkillIds"
        ),
      ],
      baselineNodeFrames: frames,
      offsetsByNodeKey: [
        "directive:small-cli-change": CGSize(
          width: 0,
          height: 160
        )
      ],
      compact: false
    )

    let visualDirectiveFrame = try #require(
      RelationshipMapLayoutState.visualFrames(
        frames,
        offsetsByNodeKey: [
          "directive:small-cli-change": CGSize(
            width: 0,
            height: 160
          )
        ]
      )["directive:small-cli-change"]
    )
    let incomingRoute = try #require(
      routes.first { $0.toKey == "directive:small-cli-change" }
    )
    let outgoingRoute = try #require(
      routes.first { $0.fromKey == "directive:small-cli-change" }
    )

    #expect(incomingRoute.endPoint.x == visualDirectiveFrame.minX)
    #expect(incomingRoute.endPoint.y == visualDirectiveFrame.midY)
    #expect(outgoingRoute.startPoint.x == visualDirectiveFrame.maxX)
    #expect(outgoingRoute.startPoint.y == visualDirectiveFrame.midY)
  }

  @Test
  func routeGeometryKeepsMultipleEdgeEndpointsCenteredAtCardBoundary() throws {
    let frames = relationshipRouteFrames()
    let routes = RelationshipMapRouteGeometry.routeRecords(
      edges: [
        WorkspaceSessionMapEdge(
          fromKey: "directive:small-cli-change",
          toKey: "skill:autonomous-agent-loop",
          reason: "directive.forbiddenSkillIds"
        ),
        WorkspaceSessionMapEdge(
          fromKey: "directive:small-cli-change",
          toKey: "skill:opencode-cli",
          reason: "directive.requiredSkillIds"
        ),
      ],
      baselineNodeFrames: frames,
      offsetsByNodeKey: [
        "directive:small-cli-change": CGSize(
          width: 0,
          height: 80
        )
      ],
      compact: false
    )

    let visualDirectiveFrame = try #require(
      RelationshipMapLayoutState.visualFrames(
        frames,
        offsetsByNodeKey: [
          "directive:small-cli-change": CGSize(
            width: 0,
            height: 80
          )
        ]
      )["directive:small-cli-change"]
    )

    #expect(routes.count == 2)

    for route in routes {
      #expect(route.startPoint.x == visualDirectiveFrame.maxX)
      #expect(route.startPoint.y == visualDirectiveFrame.midY)
    }
  }

  @Test
  func dragStateStartsOnlyAfterMeaningfulMovement() {
    #expect(
      !RelationshipMapDragState.shouldBeginDrag(
        translation: CGSize(
          width: 0,
          height: 4
        )
      )
    )
    #expect(
      RelationshipMapDragState.shouldBeginDrag(
        translation: CGSize(
          width: 0,
          height: RelationshipMapDragState.minimumDragDistance
        )
      )
    )
  }

  @Test
  func automationIdentifierSanitizesNodeKeysDeterministically() {
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "directive:small-cli-change")
        == "relationship-map-node-directive-small-cli-change-38b4f3eb"
    )
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "directive:small-cli-change")
        == RelationshipMapAutomationIdentifier.node(key: "directive:small-cli-change")
    )
  }

  @Test
  func automationIdentifierKeepsDistinctNodeKindsDistinct() {
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "directive:opencode-cli")
        != RelationshipMapAutomationIdentifier.node(key: "skill:opencode-cli")
    )
  }

  @Test
  func automationIdentifierKeepsCollisionProneKeysDistinct() {
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "session:a_b")
        == "relationship-map-node-session-a-b-2e0b257f"
    )
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "session:a-b")
        == "relationship-map-node-session-a-b-5e36fdad"
    )
    #expect(
      RelationshipMapAutomationIdentifier.node(key: "session:a_b")
        != RelationshipMapAutomationIdentifier.node(key: "session:a-b")
    )
  }

  @Test
  func automationIdentifierHandlesUnsafeCharacters() {
    #expect(
      RelationshipMapAutomationIdentifier.sanitizedToken("  Persona/Some_ID!?  ")
        == "persona-some-id"
    )
    #expect(RelationshipMapAutomationIdentifier.sanitizedToken("!?") == "unknown")
  }

  @Test
  func dragInteractionStateLeavesSmallMovementAsSelection() {
    var dragState = RelationshipMapDragInteractionState()

    #expect(
      dragState.updatedOffset(
        for: "persona:solo-developer",
        currentOffset: .zero,
        translation: CGSize(width: 0, height: 4)
      ) == nil
    )
    #expect(
      dragState.endedOffset(
        for: "persona:solo-developer",
        currentOffset: .zero,
        translation: CGSize(width: 0, height: 4)
      ) == nil
    )
    let shouldSuppressSelection = dragState.shouldSuppressSelection(
      for: "persona:solo-developer"
    )

    #expect(!shouldSuppressSelection)
  }

  @Test
  func dragInteractionStateSuppressesSelectionAfterMeaningfulDrag() {
    var dragState = RelationshipMapDragInteractionState()
    let updatedOffset = dragState.updatedOffset(
      for: "directive:small-cli-change",
      currentOffset: .zero,
      translation: CGSize(width: 0, height: 24)
    )

    #expect(updatedOffset == CGSize(width: 0, height: 24))
    #expect(dragState.activeNodeKey == "directive:small-cli-change")

    let endedOffset = dragState.endedOffset(
      for: "directive:small-cli-change",
      currentOffset: updatedOffset ?? .zero,
      translation: CGSize(width: 0, height: 24)
    )

    #expect(endedOffset == CGSize(width: 0, height: 24))
    #expect(dragState.activeNodeKey == nil)
    let firstSuppression = dragState.shouldSuppressSelection(
      for: "directive:small-cli-change"
    )
    let secondSuppression = dragState.shouldSuppressSelection(
      for: "directive:small-cli-change"
    )

    #expect(firstSuppression)
    #expect(!secondSuppression)
  }

  private func relationshipRouteFrames() -> [String: CGRect] {
    [
      "directive:small-cli-change": CGRect(
        x: 360,
        y: 80,
        width: 170,
        height: 64
      ),
      "kit:cli-guardrails": CGRect(
        x: 600,
        y: 40,
        width: 180,
        height: 74
      ),
      "persona:solo-developer": CGRect(
        x: 160,
        y: 180,
        width: 170,
        height: 62
      ),
      "session:solo-dev": CGRect(
        x: 0,
        y: 80,
        width: 150,
        height: 44
      ),
      "skill:autonomous-agent-loop": CGRect(
        x: 820,
        y: 30,
        width: 180,
        height: 62
      ),
      "skill:opencode-cli": CGRect(
        x: 820,
        y: 160,
        width: 180,
        height: 72
      ),
    ]
  }
}
