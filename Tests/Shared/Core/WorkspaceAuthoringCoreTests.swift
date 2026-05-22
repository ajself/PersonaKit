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
}
