import ContextWorkspaceCore
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
          key: "kit:v1-cli-guardrails",
          id: "v1-cli-guardrails",
          displayName: "V1 CLI Guardrails",
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
          key: "kit:v1-cli-guardrails",
          id: "v1-cli-guardrails",
          displayName: "V1 CLI Guardrails",
          kind: .kit,
          isMissing: false,
          badges: []
        ),
      ],
      edges: [
        WorkspaceSessionMapEdge(
          fromKey: "persona:solo-developer",
          toKey: "kit:v1-cli-guardrails",
          reason: "persona.defaultKitIds"
        ),
        WorkspaceSessionMapEdge(
          fromKey: "persona:solo-developer",
          toKey: "kit:v1-cli-guardrails",
          reason: "persona.defaultKitIds"
        ),
      ],
      resolutionErrors: [],
      isFullyResolved: true
    )

    #expect(
      RelationshipMapPresentationState.relationshipSummaries(map: map) == [
        "solo-developer -> default kit -> v1-cli-guardrails"
      ]
    )
  }
}
