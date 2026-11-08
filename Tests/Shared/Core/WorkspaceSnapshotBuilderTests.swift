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
  func missingDirectoryErrorShowsAPathWithASpaceUnencoded() {
    let error = MissingPersonaKitDirectoryError(
      projectScopeURL: URL(fileURLWithPath: "/My Workspace/.personakit")
    )

    #expect(error.errorDescription == "Missing PersonaKit directory at /My Workspace/.personakit.")
  }

  @Test
  func decodeFailureShowsAPathWithASpaceUnencoded() throws {
    let projectScopeURL = URL(fileURLWithPath: "/My Workspace/.personakit")
    let sessionsURL = PersonaKitDirectory.sessionsURL(root: projectScopeURL)
    let sessionURL = sessionsURL.appendingPathComponent("bad one.session.json")
    let dependencies = try makeDependencies(
      directories: [
        PersonaKitDirectory.packsURL(root: projectScopeURL),
        sessionsURL,
      ],
      directoryContents: [sessionsURL: [sessionURL]],
      fileData: [sessionURL: Data("not json".utf8)]
    )
    let builder = WorkspaceSnapshotBuilder(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try builder.build(workspaceURL: URL(fileURLWithPath: "/My Workspace"))
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(
        error.message.hasPrefix(
          "Failed to decode /My Workspace/.personakit/Sessions/bad one.session.json: "
        )
      )
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

  @Test
  func buildByScopesRecordsShadowedGlobalEntity() throws {
    let scopes = Self.scopeSet()
    let fixture = try makeShadowFixture(
      scopes: scopes,
      globalPersonas: ["p"],
      projectPersonas: ["p"],
      globalSessions: [],
      projectSessions: []
    )
    let snapshot = try fixture.build(scopes: scopes)

    #expect(snapshot.personas.map(\.id) == ["p"])
    #expect(snapshot.personas[0].sourceScope == .project)
    #expect(snapshot.personas[0].shadowedScope == .global)
    #expect(snapshot.personas[0].fileURL == Self.personaFileURL(root: Self.projectRoot))
    #expect(snapshot.personas[0].shadowedFileURL == Self.personaFileURL(root: Self.globalRoot))
  }

  @Test
  func buildByScopesRecordsShadowedGlobalSession() throws {
    let scopes = Self.scopeSet()
    let fixture = try makeShadowFixture(
      scopes: scopes,
      globalPersonas: [],
      projectPersonas: [],
      globalSessions: ["s"],
      projectSessions: ["s"]
    )
    let snapshot = try fixture.build(scopes: scopes)

    #expect(snapshot.sessions.map(\.id) == ["s"])
    #expect(snapshot.sessions[0].sourceScope == .project)
    #expect(snapshot.sessions[0].shadowedScope == .global)
    #expect(snapshot.sessions[0].fileURL == Self.sessionFileURL(root: Self.projectRoot))
    #expect(snapshot.sessions[0].shadowedFileURL == Self.sessionFileURL(root: Self.globalRoot))
  }

  @Test
  func buildByScopesLeavesUnshadowedNil() throws {
    let scopes = Self.scopeSet()
    let fixture = try makeShadowFixture(
      scopes: scopes,
      globalPersonas: ["p"],
      projectPersonas: [],
      globalSessions: ["s"],
      projectSessions: []
    )
    let snapshot = try fixture.build(scopes: scopes)

    #expect(snapshot.personas.map(\.id) == ["p"])
    #expect(snapshot.personas[0].sourceScope == .global)
    #expect(snapshot.personas[0].shadowedScope == nil)
    #expect(snapshot.personas[0].shadowedFileURL == nil)
    #expect(snapshot.sessions[0].sourceScope == .global)
    #expect(snapshot.sessions[0].shadowedScope == nil)
    #expect(snapshot.sessions[0].shadowedFileURL == nil)
  }

  @Test
  func buildByScopesWithGlobalOnly() throws {
    let scopes = Self.scopeSet(project: nil)
    let fixture = try makeShadowFixture(
      scopes: scopes,
      globalPersonas: ["p"],
      projectPersonas: [],
      globalSessions: ["s"],
      projectSessions: []
    )
    let snapshot = try fixture.build(scopes: scopes)

    #expect(snapshot.personas.map(\.sourceScope) == [.global])
    #expect(snapshot.sessions.map(\.sourceScope) == [.global])
    #expect(snapshot.personas[0].shadowedScope == nil)
    #expect(snapshot.sessions[0].shadowedScope == nil)
    #expect(snapshot.personas[0].shadowedFileURL == nil)
    #expect(snapshot.sessions[0].shadowedFileURL == nil)
  }

  private static let projectRoot = URL(fileURLWithPath: "/Workspace/.personakit")
  private static let globalRoot = URL(fileURLWithPath: "/Global/.personakit")

  private static func scopeSet(project: URL? = projectRoot, global: URL = globalRoot) -> ScopeSet {
    ScopeSet(projectScopeURL: project, globalScopeURL: global)
  }

  private static func personaFileURL(root: URL) -> URL {
    root.appendingPathComponent("Packs/personas/p.persona.json").standardizedFileURL
  }

  private static func sessionFileURL(root: URL) -> URL {
    PersonaKitDirectory.sessionsURL(root: root).appendingPathComponent("s.session.json").standardizedFileURL
  }

  /// Builds a builder over in-memory persona and session files placed in the given scopes.
  private func makeShadowFixture(
    scopes: ScopeSet,
    globalPersonas: [String],
    projectPersonas: [String],
    globalSessions: [String],
    projectSessions: [String]
  ) throws -> WorkspaceSnapshotBuilder {
    var directories: [URL] = []
    var directoryContents: [URL: [URL]] = [:]
    var fileData: [URL: Data] = [:]

    let placements: [(root: URL?, personas: [String], sessions: [String])] = [
      (scopes.globalScopeURL, globalPersonas, globalSessions),
      (scopes.projectScopeURL, projectPersonas, projectSessions),
    ]

    for placement in placements {
      guard let root = placement.root else { continue }

      let personasURL = root.appendingPathComponent("Packs/personas")
      let sessionsURL = PersonaKitDirectory.sessionsURL(root: root)
      directories.append(contentsOf: [PersonaKitDirectory.packsURL(root: root), personasURL, sessionsURL])

      for id in placement.personas {
        let fileURL = personasURL.appendingPathComponent("\(id).persona.json")
        directoryContents[personasURL, default: []].append(fileURL)
        fileData[fileURL] = try encode(
          Persona(
            id: id,
            version: "1.0",
            name: "\(id) in \(root.path())",
            summary: "",
            responsibilities: [],
            values: [],
            nonGoals: [],
            defaultKitIds: [],
            allowedSkillIds: [],
            forbiddenSkillIds: []
          )
        )
      }

      for id in placement.sessions {
        let fileURL = sessionsURL.appendingPathComponent("\(id).session.json")
        directoryContents[sessionsURL, default: []].append(fileURL)
        fileData[fileURL] = try encode(
          SessionFile(id: id, personaId: "p", directiveId: "d", kitOverrides: nil)
        )
      }
    }

    let dependencies = try makeDependencies(
      directories: directories,
      directoryContents: directoryContents,
      fileData: fileData
    )
    return WorkspaceSnapshotBuilder(globalScopeURL: scopes.globalScopeURL, dependencies: dependencies)
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
