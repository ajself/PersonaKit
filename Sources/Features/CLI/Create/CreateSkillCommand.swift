import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateSkillCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "skill",
    abstract: "Create a skill JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Skill id.")
  var id: String?

  @Option(name: .customLong("name"), help: "Skill name.")
  var name: String?

  @Option(name: .customLong("description"), help: "Skill description.")
  var skillDescription: String?

  @Option(name: .customLong("provided-by"), help: "Provider description (the concrete host tool).")
  var providedBy: [String] = []

  @Option(
    name: .customLong("capability"),
    help: "Host-neutral capability: \(SkillCapability.vocabulary.joined(separator: ", "))."
  )
  var capabilities: [String] = []

  @Option(name: .customLong("risk-level"), help: "Risk level: low, medium, or high.")
  var riskLevel: String?

  @Flag(name: .customLong("requires-human-review"), help: "Require human review for this skill.")
  var requiresHumanReview = false

  @Option(name: .customLong("risk-note"), help: "Risk note.")
  var riskNotes: [String] = []

  @Option(name: .customLong("note"), help: "Skill note.")
  var notes: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let prompter = CreatePrompter()

      var resolvedName = CreateCommandHelpers.trimmed(name)
      if resolvedName.isEmpty, prompter.isInteractive {
        resolvedName = prompter.promptRequired("Skill name")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedName.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedName)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Skill id", source: resolvedName)
      }

      var resolvedDescription = CreateCommandHelpers.trimmed(skillDescription)
      if resolvedDescription.isEmpty, prompter.isInteractive {
        resolvedDescription = prompter.promptRequired("Skill description")
      }

      let resolvedProvidedBy = prompter.promptCSVIfNeeded(
        values: providedBy,
        label: "Provided by (comma-separated)",
        hint: nil
      )
      let resolvedCapabilities = prompter.promptCSVIfNeeded(
        values: capabilities,
        label: "Capabilities (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Allowed capabilities",
          values: Set(SkillCapability.vocabulary)
        )
      )
      var resolvedRiskLevel = CreateCommandHelpers.trimmed(riskLevel)
      if resolvedRiskLevel.isEmpty {
        resolvedRiskLevel = "medium"
      }
      if prompter.isInteractive, CreateCommandHelpers.trimmed(riskLevel).isEmpty {
        resolvedRiskLevel = try prompter.promptRiskLevel(defaultValue: resolvedRiskLevel)
      }
      try CreateCommandHelpers.validateRiskLevel(resolvedRiskLevel)

      let resolvedRiskNotes = prompter.promptCSVIfNeeded(
        values: riskNotes,
        label: "Risk notes (comma-separated)",
        hint: nil
      )
      let resolvedNotes = prompter.promptCSVIfNeeded(
        values: notes,
        label: "Notes (comma-separated)",
        hint: nil
      )
      let resolvedRequiresReview =
        prompter.isInteractive && !requiresHumanReview
        ? prompter.promptYesNo(label: "Requires human review", defaultValue: false)
        : requiresHumanReview

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id/--name" : nil,
          resolvedName.isEmpty ? "--name" : nil,
          resolvedDescription.isEmpty ? "--description" : nil,
        ],
        example:
          "personakit create skill --name \"codex-cli\" --description \"Use the local Codex CLI.\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceSkillDraft(
        id: resolvedID,
        name: resolvedName,
        description: resolvedDescription,
        providedBy: resolvedProvidedBy,
        capabilities: resolvedCapabilities,
        riskLevel: resolvedRiskLevel,
        requiresHumanReview: resolvedRequiresReview,
        riskNotes: resolvedRiskNotes,
        notes: resolvedNotes
      )
      let builder = WorkspaceSkillDraftBuilder()
      let rawJSON = try builder.buildRawJSON(draft: draft)
      let validation = builder.validate(draft: draft)
      let manager = WorkspaceLibraryEntityManager()
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .skill
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "skill",
        entityID: CreateCommandHelpers.normalizedID(draft.id),
        destinationURL: destinationURL,
        warnings: validation.warnings,
        renderedContent: rawJSON,
        dryRun: shared.dryRun,
        force: shared.force,
        jsonOutput: shared.jsonOutput,
        prompter: prompter
      ) {
        try manager.saveRawJSON(
          workspaceURL: rootURL,
          itemID: draft.id,
          rawJSON: rawJSON,
          entityType: .skill
        )
      }
    }
  }
}
