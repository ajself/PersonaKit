import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

struct WorkspaceRelationshipMapBuilderTests {
  @Test
  func relationshipMapOrderingIsDeterministicAcrossRuns() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let first = try builder.build(workspaceURL: workspaceURL)
    let second = try builder.build(workspaceURL: workspaceURL)

    #expect(first == second)
  }

  @Test
  func relationshipMapPrefersProjectEntitiesOverGlobalScope() throws {
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

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: globalScopeURL)
    let map = try builder.build(workspaceURL: workspaceURL)

    let codexNode = try #require(
      map.nodes.first(where: { $0.key == "skill:codex-cli" })
    )
    #expect(codexNode.displayName == "Codex CLI")
  }

  @Test
  func relationshipMapDeduplicatesDuplicateMissingReferencesForSameSource() throws {
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
        defaultKitIds: [
          "missing-kit",
          "missing-kit",
          "missing-kit",
        ],
        allowedSkillIds: persona.allowedSkillIds,
        forbiddenSkillIds: persona.forbiddenSkillIds
      )
    }

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let map = try builder.build(workspaceURL: workspaceURL)

    let missingKitNode = try #require(
      map.nodes.first(where: { $0.key == "kit:missing-kit" })
    )
    #expect(missingKitNode.isMissing)

    let duplicateMissingKitErrors = map.resolutionErrors.filter { error in
      error.sourceType == .persona
        && error.sourceId == "senior-swiftui-engineer"
        && error.field == "defaultKitIds"
        && error.missingId == "missing-kit"
    }
    #expect(duplicateMissingKitErrors.count == 1)

    let duplicateEdges = map.edges.filter { edge in
      edge.fromKey == "persona:senior-swiftui-engineer"
        && edge.toKey == "kit:missing-kit"
        && edge.reason == "persona.defaultKitIds"
    }
    #expect(duplicateEdges.count == 1)
  }

  @Test
  func relationshipMapIncludesUnreferencedEssentialNodesFromScope() throws {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let globalScopeURL = try makeTempDirectory().appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)
    try copyFixtureKit(to: globalScopeURL)

    let globalEssentialURL =
      globalScopeURL.appendingPathComponent("Packs/essentials/workspace-only-doc.md")
    try Data("# Workspace-only Essential\n".utf8).write(to: globalEssentialURL, options: [.atomic])

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: globalScopeURL)
    let map = try builder.build(workspaceURL: workspaceURL)

    let workspaceOnlyEssential = try #require(
      map.nodes.first(where: { $0.key == "essential:workspace-only-doc" })
    )
    #expect(!workspaceOnlyEssential.isMissing)
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
