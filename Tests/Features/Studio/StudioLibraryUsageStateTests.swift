import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryUsageStateTests {
  @Test
  func usersAreTheSourcesOfIncomingEdgesOnly() {
    let map = makeMap(
      nodes: [
        node("session:solo-dev"),
        node("persona:solo-developer"),
        node("kit:cli-guardrails"),
      ],
      edges: [
        edge("session:solo-dev", "persona:solo-developer", "session.personaId"),
        edge("persona:solo-developer", "kit:cli-guardrails", "persona.defaultKitIds"),
      ]
    )

    #expect(
      StudioLibraryUsageState.users(of: "persona:solo-developer", in: map).map(\.key) == ["session:solo-dev"]
    )
    #expect(
      StudioLibraryUsageState.users(of: "kit:cli-guardrails", in: map).map(\.key) == ["persona:solo-developer"]
    )
    #expect(StudioLibraryUsageState.users(of: "session:solo-dev", in: map).isEmpty)
  }

  @Test
  func usersAreOrderedByKindThenID() {
    let map = makeMap(
      nodes: [
        node("persona:zeta"),
        node("session:beta"),
        node("persona:alpha"),
        node("session:alpha"),
        node("kit:shared"),
      ],
      edges: [
        edge("persona:zeta", "kit:shared", "persona.defaultKitIds"),
        edge("session:beta", "kit:shared", "session.kitOverrides"),
        edge("persona:alpha", "kit:shared", "persona.defaultKitIds"),
        edge("session:alpha", "kit:shared", "session.kitOverrides"),
      ]
    )

    #expect(
      StudioLibraryUsageState.users(of: "kit:shared", in: map).map(\.key) == [
        "session:alpha",
        "session:beta",
        "persona:alpha",
        "persona:zeta",
      ]
    )
  }

  @Test
  func usersAreDeduplicatedAcrossRepeatedEdgesAndNodes() {
    let map = makeMap(
      nodes: [
        node("session:solo-dev"),
        node("session:solo-dev"),
        node("kit:cli-guardrails"),
      ],
      edges: [
        edge("session:solo-dev", "kit:cli-guardrails", "session.kitOverrides"),
        edge("session:solo-dev", "kit:cli-guardrails", "session.kitOverrides"),
        edge("session:solo-dev", "kit:cli-guardrails", "persona.defaultKitIds"),
      ]
    )

    #expect(
      StudioLibraryUsageState.users(of: "kit:cli-guardrails", in: map).map(\.key) == ["session:solo-dev"]
    )
  }

  @Test
  func usersMixDirectivesAndKitsForASkill() {
    let map = makeMap(
      nodes: [
        node("skill:read-repo"),
        node("kit:cli-guardrails"),
        node("directive:small-cli-change"),
        node("kit:app-review"),
      ],
      edges: [
        edge("kit:cli-guardrails", "skill:read-repo", "kit.skillIds"),
        edge("directive:small-cli-change", "skill:read-repo", "directive.requiresSkillIds"),
        edge("kit:app-review", "skill:read-repo", "kit.skillIds"),
      ]
    )

    let users = StudioLibraryUsageState.users(of: "skill:read-repo", in: map)

    #expect(users.map(\.key) == ["directive:small-cli-change", "kit:app-review", "kit:cli-guardrails"])
    #expect(users.map(\.kind) == [.directive, .kit, .kit])
  }

  @Test
  func nodeWithNoIncomingEdgesHasNoUsers() {
    let map = makeMap(
      nodes: [
        node("persona:unused"),
        node("session:solo-dev"),
        node("persona:solo-developer"),
      ],
      edges: [
        edge("session:solo-dev", "persona:solo-developer", "session.personaId")
      ]
    )

    #expect(StudioLibraryUsageState.users(of: "persona:unused", in: map).isEmpty)
    #expect(StudioLibraryUsageState.users(of: "persona:not-in-graph", in: map).isEmpty)
  }

  @Test
  func builderGraphOfDemoWorkspaceYieldsExpectedUsers() throws {
    let workspaceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/studio-demo-workspace", isDirectory: true)
    let map = try WorkspaceRelationshipMapBuilder(globalScopeProvider: { nil })
      .build(workspaceURL: workspaceURL)

    #expect(
      StudioLibraryUsageState.users(of: "persona:solo-developer", in: map).map(\.key) == ["session:solo-dev"]
    )
    #expect(
      StudioLibraryUsageState.users(of: "kit:cli-guardrails", in: map).map(\.key) == ["persona:solo-developer"]
    )
    #expect(StudioLibraryUsageState.users(of: "session:solo-dev", in: map).isEmpty)
  }

  @Test
  func nodeKeyMatchesBuilderKeysForEveryLibrarySection() {
    #expect(StudioLibraryUsageState.nodeKey(kind: .persona, id: "solo-developer") == "persona:solo-developer")
    #expect(SidebarItem.personas.libraryNodeKind == .persona)
    #expect(SidebarItem.directives.libraryNodeKind == .directive)
    #expect(SidebarItem.kits.libraryNodeKind == .kit)
    #expect(SidebarItem.skills.libraryNodeKind == .skill)
    #expect(SidebarItem.sessions.libraryNodeKind == nil)
    #expect(SidebarItem.validationResults.libraryNodeKind == nil)
  }

  private func node(_ key: String) -> WorkspaceSessionMapNode {
    let parts = key.split(separator: ":", maxSplits: 1).map(String.init)

    return WorkspaceSessionMapNode(
      key: key,
      id: parts[1],
      displayName: parts[1],
      kind: WorkspaceSessionMapNodeKind(rawValue: parts[0]) ?? .session,
      isMissing: false,
      badges: []
    )
  }

  private func edge(
    _ fromKey: String,
    _ toKey: String,
    _ reason: String
  ) -> WorkspaceSessionMapEdge {
    WorkspaceSessionMapEdge(fromKey: fromKey, toKey: toKey, reason: reason)
  }

  private func makeMap(
    nodes: [WorkspaceSessionMapNode],
    edges: [WorkspaceSessionMapEdge]
  ) -> WorkspaceSessionMap {
    WorkspaceSessionMap(
      nodes: nodes,
      edges: edges,
      resolutionErrors: [],
      isFullyResolved: true
    )
  }
}
