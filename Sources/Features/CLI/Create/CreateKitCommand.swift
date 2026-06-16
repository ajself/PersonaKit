import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateKitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "kit",
    abstract: "Create a kit JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Kit id.")
  var id: String?

  @Option(name: .customLong("name"), help: "Kit name.")
  var name: String?

  @Option(name: .customLong("summary"), help: "Kit summary.")
  var summary: String?

  @Option(name: .customLong("essential"), help: "Essential id.")
  var essentialIDs: [String] = []

  @Option(name: .customLong("reference"), help: "Attached reference id.")
  var referenceIDs: [String] = []

  @Option(name: .customLong("intent"), help: "Included intent template id.")
  var intentIDs: [String] = []

  @Option(name: .customLong("skill"), help: "Skill id.")
  var skillIDs: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let references = try CreateCommandHelpers.loadReferences(rootURL: rootURL)
      let prompter = CreatePrompter()

      var resolvedName = CreateCommandHelpers.trimmed(name)
      if resolvedName.isEmpty, prompter.isInteractive {
        resolvedName = prompter.promptRequired("Kit name")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedName.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedName)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Kit id", source: resolvedName)
      }

      var resolvedSummary = CreateCommandHelpers.trimmed(summary)
      if resolvedSummary.isEmpty, prompter.isInteractive {
        resolvedSummary = prompter.promptRequired("Kit summary")
      }

      let resolvedEssentialIDs = prompter.promptCSVIfNeeded(
        values: essentialIDs,
        label: "Essential ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known essentials",
          values: references.essentialIDs
        )
      )
      let resolvedReferenceIDs = prompter.promptCSVIfNeeded(
        values: referenceIDs,
        label: "Reference ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known references",
          values: references.referenceIDs
        )
      )
      let resolvedIntentIDs = prompter.promptCSVIfNeeded(
        values: intentIDs,
        label: "Intent template ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known intents",
          values: references.intentIDs
        )
      )
      let resolvedSkillIDs = prompter.promptCSVIfNeeded(
        values: skillIDs,
        label: "Skill ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known skills",
          values: references.skillIDs
        )
      )

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id/--name" : nil,
          resolvedName.isEmpty ? "--name" : nil,
          resolvedSummary.isEmpty ? "--summary" : nil,
        ],
        example:
          "personakit create kit --name \"Sprint Planning\" --summary \"Shared planning context.\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceKitDraft(
        id: resolvedID,
        name: resolvedName,
        summary: resolvedSummary,
        essentialIds: resolvedEssentialIDs,
        referenceIds: resolvedReferenceIDs,
        intentTemplateIds: resolvedIntentIDs,
        skillIds: resolvedSkillIDs
      )
      let builder = WorkspaceKitDraftBuilder()
      let rawJSON = try builder.buildRawJSON(
        draft: draft,
        knownEssentialIDs: references.essentialIDs,
        knownReferenceIDs: references.referenceIDs,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs
      )
      let validation = builder.validate(
        draft: draft,
        knownEssentialIDs: references.essentialIDs,
        knownReferenceIDs: references.referenceIDs,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs
      )
      let manager = WorkspaceLibraryEntityManager()
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .kit
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "kit",
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
          entityType: .kit
        )
      }
    }
  }
}
