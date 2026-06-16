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
  func intentAndSkillRiskLevelsNormalizeToLowercase() throws {
    let intentJSON = try WorkspaceIntentDraftBuilder().buildRawJSON(
      draft: WorkspaceIntentDraft(
        id: "closeout-review",
        name: "Closeout Review",
        description: "Prepare the closeout packet.",
        parameters: [],
        includesEssentialIds: [],
        requiresSkillIds: [],
        riskLevel: "HIGH",
        requiresHumanReview: true,
        riskNotes: []
      )
    )
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

    let intentObject = try #require(
      JSONSerialization.jsonObject(with: Data(intentJSON.utf8)) as? [String: Any]
    )
    let intentRisk = try #require(intentObject["risk"] as? [String: Any])
    #expect(intentRisk["level"] as? String == "high")

    let skillObject = try #require(
      JSONSerialization.jsonObject(with: Data(skillJSON.utf8)) as? [String: Any]
    )
    let skillRisk = try #require(skillObject["risk"] as? [String: Any])
    #expect(skillRisk["level"] as? String == "low")
  }

  @Test
  func kitDraftBuilderEmitsReferenceAndIntentIds() throws {
    let kitJSON = try WorkspaceKitDraftBuilder().buildRawJSON(
      draft: WorkspaceKitDraft(
        id: "review-guardrails",
        name: "Review Guardrails",
        summary: "Shared review context.",
        essentialIds: ["review-boundaries"],
        referenceIds: ["review-checklist"],
        intentTemplateIds: ["behavior-preserving-review"],
        skillIds: ["read-only-review"]
      )
    )

    let kitObject = try #require(
      JSONSerialization.jsonObject(with: Data(kitJSON.utf8)) as? [String: Any]
    )
    #expect(kitObject["referenceIds"] as? [String] == ["review-checklist"])
    #expect(kitObject["intentTemplateIds"] as? [String] == ["behavior-preserving-review"])
  }

  @Test
  func kitDraftBuilderWarnsOnUnknownReferenceAndIntentIds() {
    let validation = WorkspaceKitDraftBuilder().validate(
      draft: WorkspaceKitDraft(
        id: "review-guardrails",
        name: "Review Guardrails",
        summary: "Shared review context.",
        essentialIds: [],
        referenceIds: ["missing-reference"],
        intentTemplateIds: ["missing-intent"],
        skillIds: []
      ),
      knownReferenceIDs: [],
      knownIntentIDs: []
    )

    #expect(validation.errors.isEmpty)
    #expect(validation.warnings.contains("Unknown reference ids: missing-reference."))
    #expect(validation.warnings.contains("Unknown intent ids: missing-intent."))
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
  func referenceDraftBuilderRejectsEmptyTriggerRules() {
    let builder = WorkspaceReferenceDraftBuilder()
    let draft = WorkspaceReferenceDraft(
      id: "swift-style-guide",
      name: "Swift Style Guide",
      summary: "Deeper Swift rationale.",
      pathGlobs: [],
      referenceTags: []
    )

    #expect(throws: (any Error).self) {
      _ = try builder.buildRawJSON(draft: draft)
    }
  }

  @Test
  func referenceDraftBuilderEmitsTriggerRules() throws {
    let json = try WorkspaceReferenceDraftBuilder().buildRawJSON(
      draft: WorkspaceReferenceDraft(
        id: "swift-style-guide",
        name: "Swift Style Guide",
        summary: "Deeper Swift rationale.",
        pathGlobs: ["**/*.swift"],
        referenceTags: ["swift"]
      )
    )

    let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    #expect(object["id"] as? String == "swift-style-guide")
    let triggerRules = try #require(object["triggerRules"] as? [[String: Any]])
    #expect(triggerRules.count == 1)
    #expect(triggerRules.first?["pathGlobs"] as? [String] == ["**/*.swift"])
  }
}
