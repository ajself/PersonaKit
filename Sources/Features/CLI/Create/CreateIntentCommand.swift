import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateIntentCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "intent",
    abstract: "Create an intent template JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Intent id.")
  var id: String?

  @Option(name: .customLong("name"), help: "Intent name.")
  var name: String?

  @Option(name: .customLong("description"), help: "Intent description.")
  var intentDescription: String?

  @Option(name: .customLong("parameter"), help: "Intent parameter in name:type[:required] form.")
  var parameters: [String] = []

  @Option(name: .customLong("include-essential"), help: "Included essential id.")
  var essentialIDs: [String] = []

  @Option(name: .customLong("require-skill"), help: "Required skill id.")
  var skillIDs: [String] = []

  @Option(name: .customLong("risk-level"), help: "Risk level: low, medium, or high.")
  var riskLevel: String?

  @Flag(name: .customLong("requires-human-review"), help: "Require human review for this intent.")
  var requiresHumanReview = false

  @Option(name: .customLong("risk-note"), help: "Risk note.")
  var riskNotes: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let references = try CreateCommandHelpers.loadReferences(rootURL: rootURL)
      let prompter = CreatePrompter()

      var resolvedName = CreateCommandHelpers.trimmed(name)
      if resolvedName.isEmpty, prompter.isInteractive {
        resolvedName = prompter.promptRequired("Intent name")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedName.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedName)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Intent id", source: resolvedName)
      }

      var resolvedDescription = CreateCommandHelpers.trimmed(intentDescription)
      if resolvedDescription.isEmpty, prompter.isInteractive {
        resolvedDescription = prompter.promptRequired("Intent description")
      }

      var resolvedParameters = try parameters.map(CreateCommandHelpers.parseIntentParameter)
      if prompter.isInteractive, resolvedParameters.isEmpty {
        resolvedParameters = try prompter.promptRepeatedText("Parameter (name:type[:required])")
          .map(CreateCommandHelpers.parseIntentParameter)
      }

      let resolvedEssentialIDs = prompter.promptCSVIfNeeded(
        values: essentialIDs,
        label: "Included essential ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known essentials",
          values: references.essentialIDs
        )
      )
      let resolvedSkillIDs = prompter.promptCSVIfNeeded(
        values: skillIDs,
        label: "Required skill ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known skills",
          values: references.skillIDs
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
          "personakit create intent --name \"Closeout Review\" --description \"Prepare the closeout review packet.\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceIntentDraft(
        id: resolvedID,
        name: resolvedName,
        description: resolvedDescription,
        parameters: resolvedParameters,
        includesEssentialIds: resolvedEssentialIDs,
        requiresSkillIds: resolvedSkillIDs,
        riskLevel: resolvedRiskLevel,
        requiresHumanReview: resolvedRequiresReview,
        riskNotes: resolvedRiskNotes
      )
      let builder = WorkspaceIntentDraftBuilder()
      let rawJSON = try builder.buildRawJSON(
        draft: draft,
        knownEssentialIDs: references.essentialIDs,
        knownSkillIDs: references.skillIDs
      )
      let validation = builder.validate(
        draft: draft,
        knownEssentialIDs: references.essentialIDs,
        knownSkillIDs: references.skillIDs
      )
      let manager = WorkspaceLibraryEntityManager()
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .intent
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "intent",
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
          entityType: .intent
        )
      }
    }
  }
}
