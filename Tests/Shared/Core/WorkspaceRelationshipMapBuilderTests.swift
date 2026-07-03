import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

struct WorkspaceRelationshipMapBuilderTests {
  @Test
  func relationshipMapOrderingIsDeterministicAcrossRuns() throws {
    let (workspaceURL, _) = try makeWorkspaceWithProjectFixture()

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let first = try builder.build(workspaceURL: workspaceURL)
    let second = try builder.build(workspaceURL: workspaceURL)

    #expect(first == second)
  }

  @Test
  func relationshipMapIncludesSessionNodesAndEdges() throws {
    let (workspaceURL, _) = try makeWorkspaceWithProjectFixture()

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let map = try builder.build(workspaceURL: workspaceURL)

    let sessionNode = try #require(
      map.nodes.first { $0.key == "session:senior-swiftui-engineer_apply-style" }
    )

    #expect(sessionNode.id == "senior-swiftui-engineer_apply-style")
    #expect(sessionNode.kind == .session)

    #expect(
      map.edges.contains(
        WorkspaceSessionMapEdge(
          fromKey: "session:senior-swiftui-engineer_apply-style",
          toKey: "persona:senior-swiftui-engineer",
          reason: "session.personaId"
        )
      )
    )

    #expect(
      map.edges.contains(
        WorkspaceSessionMapEdge(
          fromKey: "session:senior-swiftui-engineer_apply-style",
          toKey: "directive:apply-style",
          reason: "session.directiveId"
        )
      )
    )
  }

  @Test
  func relationshipMapReportsInvalidSessionWithoutDroppingValidGraph() throws {
    let (workspaceURL, projectScopeURL) = try makeWorkspaceWithProjectFixture()
    let brokenSessionURL = projectScopeURL.appendingPathComponent("Sessions/broken.session.json")
    try Data("{not-json".utf8).write(to: brokenSessionURL, options: [.atomic])

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let map = try builder.build(workspaceURL: workspaceURL)

    #expect(
      map.nodes.contains { $0.key == "session:senior-swiftui-engineer_apply-style" }
    )
    #expect(
      map.edges.contains(
        WorkspaceSessionMapEdge(
          fromKey: "persona:senior-swiftui-engineer",
          toKey: "kit:swift-style",
          reason: "persona.defaultKitIds"
        )
      )
    )

    let invalidSessionError = try #require(
      map.resolutionErrors.first { error in
        if case .invalidSession(let sourceId, _, _) = error {
          return sourceId == "broken"
        }

        return false
      }
    )

    #expect(invalidSessionError.sourceType == .sessionDefinition)
    #expect(invalidSessionError.sourceId == "broken")
    #expect(invalidSessionError.field == "session")
    #expect(invalidSessionError.missingId == "broken")
    #expect(
      invalidSessionError.message
        == "Invalid session file at Sessions/broken.session.json: Failed to decode session file for broken."
    )
  }

  @Test
  func relationshipMapPrefersProjectEntitiesOverGlobalScope() throws {
    let (workspaceURL, _, globalScopeURL) = try makeWorkspaceWithProjectAndGlobalFixtures()

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

    let codexNode = try #require(map.nodes.first(where: { $0.key == "skill:codex-cli" }))
    #expect(codexNode.displayName == "Codex CLI")
  }

  @Test
  func relationshipMapDeduplicatesDuplicateMissingReferencesForSameSource() throws {
    let (workspaceURL, projectScopeURL) = try makeWorkspaceWithProjectFixture()

    let personaURL = projectScopeURL.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
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

    let missingKitNode = try #require(map.nodes.first(where: { $0.key == "kit:missing-kit" }))
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
    let (workspaceURL, _, globalScopeURL) = try makeWorkspaceWithProjectAndGlobalFixtures()

    let globalEssentialURL = globalScopeURL.appendingPathComponent("Packs/essentials/workspace-only-doc.md")
    try Data("# Workspace-only Essential\n".utf8).write(to: globalEssentialURL, options: [.atomic])

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: globalScopeURL)
    let map = try builder.build(workspaceURL: workspaceURL)

    let workspaceOnlyEssential = try #require(map.nodes.first(where: { $0.key == "essential:workspace-only-doc" }))
    #expect(!workspaceOnlyEssential.isMissing)
  }

  @Test
  func relationshipMapReportsEssentialsDirectoryReadFailures() throws {
    let (workspaceURL, projectScopeURL) = try makeWorkspaceWithProjectFixture()
    let essentialsURL = projectScopeURL.appendingPathComponent("Packs/essentials")
    let dependencies = WorkspaceRelationshipMapBuilderDependencies(
      directoryExists: { url in
        var isDirectory: ObjCBool = false

        return FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      contentsOfDirectory: { url in
        if url.standardizedFileURL == essentialsURL.standardizedFileURL {
          throw NSError(
            domain: "WorkspaceRelationshipMapBuilderTests",
            code: 1
          )
        }

        return try FileManager.default.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      },
      defaultGlobalScopeURL: { nil },
      fileExists: { url in
        FileManager.default.fileExists(atPath: url.path())
      }
    )
    let builder = WorkspaceRelationshipMapBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: workspaceURL)
      Issue.record("Expected relationship map build to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Failed to read directory"))
      #expect(error.message.contains("Packs/essentials"))
    }
  }

  @Test
  func relationshipMapTreatsBuiltInEssentialReferencesAsResolved() throws {
    let (workspaceURL, projectScopeURL) = try makeWorkspaceWithProjectFixture()
    let kitURL = projectScopeURL.appendingPathComponent("Packs/kits/swift-style.kit.json")

    try mutateJSONFile(kitURL, as: Kit.self) { kit in
      Kit(
        id: kit.id,
        version: kit.version,
        name: kit.name,
        summary: kit.summary,
        essentialIds: kit.essentialIds + [
          "persona-activation-contract",
          "skill-authorization-contract",
        ],
        skillIds: kit.skillIds
      )
    }

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let map = try builder.build(workspaceURL: workspaceURL)

    let personaContract = try #require(
      map.nodes.first { $0.key == "essential:persona-activation-contract" }
    )
    let skillContract = try #require(
      map.nodes.first { $0.key == "essential:skill-authorization-contract" }
    )

    #expect(!personaContract.isMissing)
    #expect(!skillContract.isMissing)
    #expect(
      !map.resolutionErrors.contains { error in
        error.missingId == "persona-activation-contract"
          || error.missingId == "skill-authorization-contract"
      }
    )
  }

  @Test
  func relationshipMapIncludesGroundingSkillNodesAndDirectiveEdges() throws {
    let (workspaceURL, _) = try makeWorkspaceWithProjectFixture()

    let builder = WorkspaceRelationshipMapBuilder(globalScopeURL: nil)
    let map = try builder.build(workspaceURL: workspaceURL)

    let groundingSkillNode = try #require(
      map.nodes.first(where: { $0.key == "skill:swift-style-guide-reference" })
    )
    #expect(groundingSkillNode.displayName == "Swift Style Guide Reference")
    #expect(!groundingSkillNode.isMissing)

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

  private func makeWorkspaceWithProjectFixture() throws -> (
    workspaceURL: URL,
    projectScopeURL: URL
  ) {
    let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyFixtureKit(to: projectScopeURL)

    return (workspaceURL, projectScopeURL)
  }

  private func makeWorkspaceWithProjectAndGlobalFixtures() throws -> (
    workspaceURL: URL,
    projectScopeURL: URL,
    globalScopeURL: URL
  ) {
    let (workspaceURL, projectScopeURL) = try makeWorkspaceWithProjectFixture()
    let globalScopeURL = try makeTempDirectory().appendingPathComponent(".personakit")

    try copyFixtureKit(to: globalScopeURL)

    return (workspaceURL, projectScopeURL, globalScopeURL)
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
