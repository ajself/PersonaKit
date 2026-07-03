import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

struct WorkspaceAuthoringCoreTests {
  @Test
  func writableRootResolverPrefersProjectOverGlobal() throws {
    let tempDirectory = try makeTempDirectory()
    let projectDirectory = tempDirectory.appendingPathComponent("Project")
    let projectRoot = projectDirectory.appendingPathComponent(".personakit")
    let globalHome = tempDirectory.appendingPathComponent("Home")
    let globalRoot = globalHome.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(
      at: projectRoot.appendingPathComponent("Packs"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: globalRoot.appendingPathComponent("Packs"),
      withIntermediateDirectories: true
    )

    let resolver = WorkspaceWritableRootResolver(
      scopeRootResolver: ScopeRootResolver(
        startingURL: projectDirectory,
        homeDirectory: globalHome
      )
    )

    let resolvedRoot = try resolver.resolveWritableRoot(explicitRootURL: nil)
    #expect(resolvedRoot.standardizedFileURL == projectRoot.standardizedFileURL)
  }

  @Test
  func directiveStarterTemplateProvidesPlaceholderSections() {
    let draft = WorkspaceDirectiveDraftBuilder().defaultDraft(template: .starter)

    #expect(draft.steps.count == 1)
    #expect(draft.acceptanceCriteria == ["TODO: add acceptance criteria."])
    #expect(draft.verification.count == 1)
    #expect(draft.verification.first?.kind == "manual")
  }

  @Test
  func sessionDraftBuilderRejectsUnknownReferences() {
    let draft = WorkspaceSessionDraft(
      id: "review-session",
      personaId: "missing-persona",
      directiveId: "missing-directive",
      kitOverrides: ["missing-kit"]
    )

    let validation = WorkspaceSessionDraftBuilder.validate(
      draft: draft,
      validPersonaIDs: [],
      validDirectiveIDs: [],
      validKitIDs: []
    )

    #expect(
      validation.errors
        == [
          "Persona id \"missing-persona\" is not valid.",
          "Directive id \"missing-directive\" is not valid.",
          "Kit id \"missing-kit\" is not valid.",
        ]
    )
  }

  @Test
  func essentialDraftBuilderStarterMarkdownIsDeterministic() {
    let markdown = WorkspaceEssentialDraftBuilder.buildMarkdown(
      title: "Planning Guardrails",
      body: nil,
      template: .starter
    )

    #expect(markdown == "# Planning Guardrails\n\nTODO: add essential guidance.\n")
  }

  @Test
  func skillRiskLevelsNormalizeToLowercase() throws {
    let skillJSON = try WorkspaceSkillDraftBuilder().buildRawJSON(
      draft: WorkspaceSkillDraft(
        id: "codex-cli",
        name: "codex-cli",
        description: "Use the local Codex CLI.",
        providedBy: ["tests"],
        riskLevel: "LOW",
        requiresHumanReview: false,
        riskNotes: [],
        notes: []
      )
    )

    let skillObject = try #require(
      JSONSerialization.jsonObject(with: Data(skillJSON.utf8)) as? [String: Any]
    )
    let skillRisk = try #require(skillObject["risk"] as? [String: Any])
    #expect(skillRisk["level"] as? String == "low")
  }

  @Test
  func kitDraftBuilderEmitsSkillIds() throws {
    let kitJSON = try WorkspaceKitDraftBuilder().buildRawJSON(
      draft: WorkspaceKitDraft(
        id: "review-guardrails",
        name: "Review Guardrails",
        summary: "Shared review context.",
        essentialIds: ["review-boundaries"],
        skillIds: ["read-only-review"]
      )
    )

    let kitObject = try #require(
      JSONSerialization.jsonObject(with: Data(kitJSON.utf8)) as? [String: Any]
    )
    #expect(kitObject["skillIds"] as? [String] == ["read-only-review"])
  }

  @Test
  func kitDraftBuilderWarnsOnUnknownSkillIds() {
    let validation = WorkspaceKitDraftBuilder().validate(
      draft: WorkspaceKitDraft(
        id: "review-guardrails",
        name: "Review Guardrails",
        summary: "Shared review context.",
        essentialIds: [],
        skillIds: ["missing-skill"]
      ),
      knownSkillIDs: []
    )

    #expect(validation.errors.isEmpty)
    #expect(validation.warnings.contains("Unknown skill ids: missing-skill."))
  }

  @Test
  func skillDraftBuilderEmitsSortedDedupedCapabilities() throws {
    let skillJSON = try WorkspaceSkillDraftBuilder().buildRawJSON(
      draft: WorkspaceSkillDraft(
        id: "reviewer",
        name: "Reviewer",
        description: "Reads and reports.",
        providedBy: ["Claude Code"],
        capabilities: ["run-commands", "read-only-inspection", "read-only-inspection"],
        riskLevel: "low",
        requiresHumanReview: false,
        riskNotes: [],
        notes: []
      )
    )

    let object = try #require(
      JSONSerialization.jsonObject(with: Data(skillJSON.utf8)) as? [String: Any]
    )
    #expect(object["capabilities"] as? [String] == ["read-only-inspection", "run-commands"])
  }

  @Test
  func skillDraftBuilderRejectsUnknownCapability() {
    let validation = WorkspaceSkillDraftBuilder().validate(
      draft: WorkspaceSkillDraft(
        id: "reviewer",
        name: "Reviewer",
        description: "Reads and reports.",
        providedBy: [],
        capabilities: ["file-editing"],
        riskLevel: "low",
        requiresHumanReview: false,
        riskNotes: [],
        notes: []
      )
    )

    #expect(validation.errors.contains { $0.contains("Unknown capabilities: file-editing") })
  }

  @Test
  func skillDraftBuilderOmitsTriggerRulesWhenNoGroundingHints() throws {
    let json = try WorkspaceSkillDraftBuilder().buildRawJSON(
      draft: WorkspaceSkillDraft(
        id: "swift-style-guide",
        name: "Swift Style Guide",
        description: "Deeper Swift rationale.",
        providedBy: [],
        riskLevel: "low",
        requiresHumanReview: false,
        riskNotes: [],
        notes: [],
        pathGlobs: [],
        skillTags: []
      )
    )

    let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    #expect(object["triggerRules"] == nil)
  }

  @Test
  func skillDraftBuilderEmitsTriggerRules() throws {
    let json = try WorkspaceSkillDraftBuilder().buildRawJSON(
      draft: WorkspaceSkillDraft(
        id: "swift-style-guide",
        name: "Swift Style Guide",
        description: "Deeper Swift rationale.",
        providedBy: [],
        riskLevel: "low",
        requiresHumanReview: false,
        riskNotes: [],
        notes: [],
        pathGlobs: ["**/*.swift"],
        skillTags: ["swift"]
      )
    )

    let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    #expect(object["id"] as? String == "swift-style-guide")
    let triggerRules = try #require(object["triggerRules"] as? [[String: Any]])
    #expect(triggerRules.count == 1)
    #expect(triggerRules.first?["pathGlobs"] as? [String] == ["**/*.swift"])
    #expect(triggerRules.first?["skillTags"] as? [String] == ["swift"])
  }
}
