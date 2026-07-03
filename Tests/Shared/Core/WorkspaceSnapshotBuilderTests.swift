import ContextWorkspaceCore
import Foundation
import Testing

@testable import ContextCore

/// Coverage for snapshot loading, scope precedence, and dependency stubbing behavior.
struct WorkspaceSnapshotBuilderTests {
  @Test
  func snapshotMergesProjectAndGlobalScopes() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let globalScopeURL = URL(fileURLWithPath: "/Global/.personakit")

    let globalSessionURL = globalScopeURL.appendingPathComponent("Sessions/shared-session.session.json")
    let projectSessionURL = projectScopeURL.appendingPathComponent("Sessions/shared-session.session.json")
    let globalPersonaURL = globalScopeURL.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    let projectPersonaURL = projectScopeURL.appendingPathComponent(
      "Packs/personas/senior-swiftui-engineer.persona.json"
    )
    let globalGroundingSkillURL = globalScopeURL.appendingPathComponent(
      "Packs/skills/swift-style-guide-reference.skill.json"
    )
    let projectGroundingSkillURL = projectScopeURL.appendingPathComponent(
      "Packs/skills/swift-style-guide-reference.skill.json"
    )
    let globalSkillURL = globalScopeURL.appendingPathComponent("Packs/skills/global-only-skill.skill.json")

    let globalSession = SessionFile(
      id: "shared-session",
      personaId: "global-persona",
      directiveId: "apply-style",
      kitOverrides: nil
    )
    let projectSession = SessionFile(
      id: "shared-session",
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: nil
    )
    let globalPersona = Persona(
      id: "senior-swiftui-engineer",
      version: "1.0",
      name: "Global Persona",
      summary: "Global",
      responsibilities: [],
      values: [],
      nonGoals: [],
      defaultKitIds: [],
      allowedSkillIds: [],
      forbiddenSkillIds: []
    )
    let projectPersona = Persona(
      id: "senior-swiftui-engineer",
      version: "1.0",
      name: "Project Persona",
      summary: "Project",
      responsibilities: [],
      values: [],
      nonGoals: [],
      defaultKitIds: [],
      allowedSkillIds: [],
      forbiddenSkillIds: []
    )
    let globalOnlySkill = Skill(
      id: "global-only-skill",
      version: "1.0",
      name: "Global Only Skill",
      description: "Only available in the global scope.",
      providedBy: ["tests"],
      risk: .init(
        level: "low",
        requiresHumanReview: false,
        notes: []
      ),
      notes: []
    )
    let globalGroundingSkill = Skill(
      id: "swift-style-guide-reference",
      version: "1.0",
      name: "Global Swift Style Guide Reference",
      description: "Global",
      triggerRules: [
        SkillTriggerRule(pathGlobs: ["**/*.swift"])
      ]
    )
    let projectGroundingSkill = Skill(
      id: "swift-style-guide-reference",
      version: "1.0",
      name: "Project Swift Style Guide Reference",
      description: "Project",
      triggerRules: [
        SkillTriggerRule(pathGlobs: ["**/*.swift"])
      ]
    )

    let dependencies = try makeDependencies(
      directories: [
        PersonaKitDirectory.packsURL(root: projectScopeURL),
        PersonaKitDirectory.packsURL(root: globalScopeURL),
        PersonaKitDirectory.sessionsURL(root: projectScopeURL),
        PersonaKitDirectory.sessionsURL(root: globalScopeURL),
        projectScopeURL.appendingPathComponent("Packs/personas"),
        globalScopeURL.appendingPathComponent("Packs/personas"),
        projectScopeURL.appendingPathComponent("Packs/skills"),
        globalScopeURL.appendingPathComponent("Packs/skills"),
      ],
      directoryContents: [
        PersonaKitDirectory.sessionsURL(root: globalScopeURL): [globalSessionURL],
        PersonaKitDirectory.sessionsURL(root: projectScopeURL): [projectSessionURL],
        globalScopeURL.appendingPathComponent("Packs/personas"): [globalPersonaURL],
        projectScopeURL.appendingPathComponent("Packs/personas"): [projectPersonaURL],
        globalScopeURL.appendingPathComponent("Packs/skills"): [globalGroundingSkillURL, globalSkillURL],
        projectScopeURL.appendingPathComponent("Packs/skills"): [projectGroundingSkillURL],
      ],
      fileData: [
        globalSessionURL: try encode(globalSession),
        projectSessionURL: try encode(projectSession),
        globalPersonaURL: try encode(globalPersona),
        projectPersonaURL: try encode(projectPersona),
        globalGroundingSkillURL: try encode(globalGroundingSkill),
        projectGroundingSkillURL: try encode(projectGroundingSkill),
        globalSkillURL: try encode(globalOnlySkill),
      ]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: globalScopeURL,
      dependencies: dependencies
    )
    let snapshot = try builder.build(workspaceURL: workspaceURL)

    let persona = try #require(
      snapshot.personas.first(where: { $0.id == "senior-swiftui-engineer" })
    )
    #expect(persona.sourceScope == .project)

    let globalSkill = try #require(
      snapshot.skills.first(where: { $0.id == "global-only-skill" })
    )
    #expect(globalSkill.sourceScope == .global)
    #expect(globalSkill.skillMetadata?.providedBy == ["tests"])
    #expect(globalSkill.skillMetadata?.riskLevel == "low")
    #expect(globalSkill.skillMetadata?.requiresHumanReview == false)

    let groundingSkill = try #require(
      snapshot.skills.first(where: { $0.id == "swift-style-guide-reference" })
    )
    #expect(groundingSkill.sourceScope == .project)
    #expect(groundingSkill.displayName == "Project Swift Style Guide Reference")

    let session = try #require(
      snapshot.sessions.first(where: { $0.id == "shared-session" })
    )
    #expect(session.sourceScope == .project)
    #expect(session.personaId == "senior-swiftui-engineer")
  }

  @Test
  func snapshotFailsWhenProjectPersonaKitDirectoryIsMissing() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let dependencies = try makeDependencies(
      directories: [],
      directoryContents: [:],
      fileData: [:]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: workspaceURL)
      #expect(Bool(false))
    } catch let error as MissingPersonaKitDirectoryError {
      #expect(error.projectScopeURL.path().contains("/Workspace/.personakit"))
    }
  }

  @Test
  func snapshotFailsWhenProjectPacksPathIsFile() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    let dependencies = try makeDependencies(
      directories: [],
      files: [packsURL],
      directoryContents: [:],
      fileData: [:]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: workspaceURL)
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message == "PersonaKit reserved path Packs exists but is not a directory.")
    }
  }

  @Test
  func snapshotFailsWhenSessionsPathIsFile() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let dependencies = try makeDependencies(
      directories: [
        PersonaKitDirectory.packsURL(root: projectScopeURL)
      ],
      files: [
        PersonaKitDirectory.sessionsURL(root: projectScopeURL)
      ],
      directoryContents: [:],
      fileData: [:]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: workspaceURL)
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message == "PersonaKit reserved path Sessions exists but is not a directory.")
    }
  }

  @Test
  func snapshotFailsWhenEntityPackPathIsFile() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let dependencies = try makeDependencies(
      directories: [
        PersonaKitDirectory.packsURL(root: projectScopeURL)
      ],
      files: [
        projectScopeURL.appendingPathComponent("Packs/personas")
      ],
      directoryContents: [:],
      fileData: [:]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: workspaceURL)
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message == "PersonaKit reserved path Packs/personas exists but is not a directory.")
    }
  }

  @Test
  func snapshotLoadsDirectiveWorkstreamMetadata() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let directiveURL = projectScopeURL.appendingPathComponent("Packs/directives/apply-style.directive.json")

    let directive = Directive(
      id: "apply-style",
      version: "1.0",
      title: "Apply Style",
      goal: "Keep style consistent.",
      steps: [],
      acceptanceCriteria: [],
      verification: [],
      requiresSkillIds: [],
      workstream: Directive.Workstream(
        id: "style-workstream",
        phase: "planning",
        entrySessionId: "style-session",
        requiredCloseoutSessionId: "style-closeout",
        nodes: [
          .init(sessionId: "style-session", phase: "planning"),
          .init(sessionId: "style-closeout", phase: "closeout"),
        ],
        edges: [
          .init(
            fromSessionId: "style-session",
            toSessionId: "style-closeout",
            kind: "required-closeout"
          )
        ]
      )
    )

    let dependencies = try makeDependencies(
      directories: [
        PersonaKitDirectory.packsURL(root: projectScopeURL),
        projectScopeURL.appendingPathComponent("Packs/directives"),
      ],
      directoryContents: [
        projectScopeURL.appendingPathComponent("Packs/directives"): [directiveURL]
      ],
      fileData: [
        directiveURL: try encode(directive)
      ]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    let snapshot = try builder.build(workspaceURL: workspaceURL)
    let directiveItem = try #require(snapshot.directives.first)

    #expect(directiveItem.workstreamId == "style-workstream")
    #expect(directiveItem.workstreamPhase == "planning")
  }

  private func makeDependencies(
    directories: [URL],
    files: [URL] = [],
    directoryContents: [URL: [URL]],
    fileData: [URL: Data]
  ) throws -> WorkspaceSnapshotBuilderDependencies {
    let normalizedDirectories = Set(directories.map(\.standardizedFileURL))
    let normalizedFiles = Set(files.map(\.standardizedFileURL))
    let normalizedDirectoryContents = Dictionary(
      uniqueKeysWithValues: directoryContents.map { key, value in
        (key.standardizedFileURL, value.map(\.standardizedFileURL))
      }
    )
    let normalizedFileData = Dictionary(
      uniqueKeysWithValues: fileData.map { key, value in
        (key.standardizedFileURL, value)
      }
    )

    return WorkspaceSnapshotBuilderDependencies(
      directoryExists: { url in
        normalizedDirectories.contains(url.standardizedFileURL)
      },
      fileExists: { url in
        normalizedDirectories.contains(url.standardizedFileURL)
          || normalizedFiles.contains(url.standardizedFileURL)
      },
      contentsOfDirectory: { url in
        normalizedDirectoryContents[url.standardizedFileURL] ?? []
      },
      readData: { url in
        guard let data = normalizedFileData[url.standardizedFileURL] else {
          throw WorkspaceSnapshotBuildError(message: "Missing file data for \(url.path()).")
        }

        return data
      },
      defaultGlobalScopeURL: { nil },
      validateRegistry: { _ in }
    )
  }

  private func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
  }
}
