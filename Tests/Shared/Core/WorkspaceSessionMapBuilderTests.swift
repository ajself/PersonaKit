import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

struct WorkspaceSessionMapBuilderTests {
  @Test
  func mapOrderingIsDeterministicAcrossRuns() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceSessionMapBuilder(globalScopeURL: nil)
    let first = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )
    let second = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    #expect(first == second)
  }

  @Test
  func mapBuildsExpectedGraphForFixtureSession() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceSessionMapBuilder(globalScopeURL: nil)
    let map = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    #expect(map.isFullyResolved)
    #expect(map.resolutionErrors.isEmpty)

    #expect(map.nodes.contains(where: { $0.key == "session:active-session" }))
    #expect(map.nodes.contains(where: { $0.key == "persona:senior-swiftui-engineer" }))
    #expect(map.nodes.contains(where: { $0.key == "directive:apply-style" }))
    #expect(map.nodes.contains(where: { $0.key == "kit:swift-style" }))
    #expect(map.nodes.contains(where: { $0.key == "skill:codex-cli" }))
    #expect(map.nodes.contains(where: { $0.key == "skill:tools-and-constraints" }))
    #expect(map.nodes.contains(where: { $0.key == "skill:swift-style-guide-reference" }))
    #expect(map.nodes.contains(where: { $0.key == "skill:swiftui-style-guide-reference" }))

    #expect(
      map.edges.contains(
        WorkspaceSessionMapEdge(
          fromKey: "persona:senior-swiftui-engineer",
          toKey: "kit:swift-style",
          reason: "persona.defaultKitIds"
        )
      )
    )
    #expect(
      map.edges.contains(
        WorkspaceSessionMapEdge(
          fromKey: "directive:apply-style",
          toKey: "skill:swift-style-guide-reference",
          reason: "directive.requiresSkillIds"
        )
      )
    )
  }

  @Test
  func mapIncludesMissingNodesAndResolutionErrors() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    let personaURL = projectScopeURL.appendingPathComponent(
      "Packs/personas/senior-swiftui-engineer.persona.json"
    )
    try mutateJSONFile(personaURL, as: Persona.self) { persona in
      Persona(
        id: persona.id,
        version: persona.version,
        name: persona.name,
        summary: persona.summary,
        responsibilities: persona.responsibilities,
        values: persona.values,
        nonGoals: persona.nonGoals,
        defaultKitIds: ["missing-kit"],
        allowedSkillIds: persona.allowedSkillIds,
        forbiddenSkillIds: persona.forbiddenSkillIds
      )
    }

    let directiveURL = projectScopeURL.appendingPathComponent(
      "Packs/directives/apply-style.directive.json"
    )
    try mutateJSONFile(directiveURL, as: Directive.self) { directive in
      Directive(
        id: directive.id,
        version: directive.version,
        title: directive.title,
        goal: directive.goal,
        steps: directive.steps,
        acceptanceCriteria: directive.acceptanceCriteria,
        verification: directive.verification,
        requiresSkillIds: ["missing-skill"]
      )
    }

    let builder = WorkspaceSessionMapBuilder(globalScopeURL: nil)
    let map = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    #expect(!map.isFullyResolved)
    #expect(!map.resolutionErrors.isEmpty)

    #expect(map.nodes.contains(where: { $0.key == "kit:missing-kit" && $0.isMissing }))
    #expect(map.nodes.contains(where: { $0.key == "skill:missing-skill" && $0.isMissing }))
  }

  @Test
  func mapAppliesOverrideBadgesAndDeduplicatesOverrideEdges() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceSessionMapBuilder(globalScopeURL: nil)
    let map = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [
        "repo-constraints",
        "repo-constraints",
        "  repo-constraints  ",
      ]
    )

    let repoConstraintsNode = try #require(
      map.nodes.first(where: { $0.key == "kit:repo-constraints" })
    )
    #expect(repoConstraintsNode.badges.contains("default"))
    #expect(repoConstraintsNode.badges.contains("override"))

    let overrideEdges = map.edges.filter { edge in
      edge.fromKey == "session:active-session"
        && edge.toKey == "kit:repo-constraints"
        && edge.reason == "session.kitOverrides"
    }
    #expect(overrideEdges.count == 1)
  }

  @Test
  func mapResolvesProjectAndGlobalScopeMerges() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let globalScopeURL = try makeTempDirectory().appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)
    try copyFixtureKit(to: globalScopeURL)

    let globalSkillURL = globalScopeURL.appendingPathComponent("Packs/skills/codex-cli.skill.json")
    try mutateJSONFile(globalSkillURL, as: Skill.self) { skill in
      Skill(
        id: skill.id,
        version: skill.version,
        name: "Global Codex CLI",
        description: skill.description,
        providedBy: skill.providedBy,
        risk: skill.risk,
        notes: skill.notes
      )
    }

    let builder = WorkspaceSessionMapBuilder(globalScopeURL: globalScopeURL)
    let map = try builder.build(
      workspaceURL: workspaceURL,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    let skillNode = try #require(
      map.nodes.first(where: { $0.key == "skill:codex-cli" })
    )
    #expect(skillNode.displayName == "Codex CLI")
  }

  private func mutateJSONFile<T: Codable>(
    _ fileURL: URL,
    as type: T.Type,
    mutate: (T) throws -> T
  ) throws {
    let data = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    let value = try decoder.decode(type, from: data)
    let updated = try mutate(value)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    try encoder.encode(updated).write(to: fileURL, options: [.atomic])
  }
}
