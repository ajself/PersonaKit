import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreatePersonaCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "persona",
    abstract: "Create a persona JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Persona id.")
  var id: String?

  @Option(name: .customLong("name"), help: "Persona name.")
  var name: String?

  @Option(name: .customLong("summary"), help: "Persona summary.")
  var summary: String?

  @Option(name: .customLong("responsibility"), help: "Persona responsibility.")
  var responsibilities: [String] = []

  @Option(name: .customLong("value"), help: "Persona value.")
  var values: [String] = []

  @Option(name: .customLong("non-goal"), help: "Persona non-goal.")
  var nonGoals: [String] = []

  @Option(name: .customLong("default-kit"), help: "Default kit id.")
  var defaultKitIDs: [String] = []

  @Option(name: .customLong("allow-skill"), help: "Allowed skill id.")
  var allowedSkillIDs: [String] = []

  @Option(name: .customLong("forbid-skill"), help: "Forbidden skill id.")
  var forbiddenSkillIDs: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let references = try CreateCommandHelpers.loadReferences(rootURL: rootURL)
      let prompter = CreatePrompter()

      var resolvedName = CreateCommandHelpers.trimmed(name)
      if resolvedName.isEmpty, prompter.isInteractive {
        resolvedName = prompter.promptRequired("Persona name")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedName.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedName)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(
          label: "Persona id",
          source: resolvedName
        )
      }

      var resolvedSummary = CreateCommandHelpers.trimmed(summary)
      if resolvedSummary.isEmpty, prompter.isInteractive {
        resolvedSummary = prompter.promptRequired("Persona summary")
      }

      let resolvedResponsibilities = prompter.promptCSVIfNeeded(
        values: responsibilities,
        label: "Responsibilities (comma-separated)",
        hint: nil
      )
      let resolvedValues = prompter.promptCSVIfNeeded(
        values: values,
        label: "Values (comma-separated)",
        hint: nil
      )
      let resolvedNonGoals = prompter.promptCSVIfNeeded(
        values: nonGoals,
        label: "Non-goals (comma-separated)",
        hint: nil
      )
      let resolvedDefaultKitIDs = prompter.promptCSVIfNeeded(
        values: defaultKitIDs,
        label: "Default kit ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known kits",
          values: references.kitIDs
        )
      )
      let resolvedAllowedSkillIDs = prompter.promptCSVIfNeeded(
        values: allowedSkillIDs,
        label: "Allowed skill ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known skills",
          values: references.skillIDs
        )
      )
      let resolvedForbiddenSkillIDs = prompter.promptCSVIfNeeded(
        values: forbiddenSkillIDs,
        label: "Forbidden skill ids (comma-separated)",
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
          "personakit create persona --name \"Session Planner\" --summary \"Plans milestone slices.\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspacePersonaDraft(
        id: resolvedID,
        name: resolvedName,
        summary: resolvedSummary,
        responsibilities: resolvedResponsibilities,
        values: resolvedValues,
        nonGoals: resolvedNonGoals,
        defaultKitIds: resolvedDefaultKitIDs,
        allowedSkillIds: resolvedAllowedSkillIDs,
        forbiddenSkillIds: resolvedForbiddenSkillIDs
      )
      let builder = WorkspacePersonaDraftBuilder()
      let rawJSON = try builder.buildRawJSON(
        draft: draft,
        existingPersonaIDs: [],
        knownKitIDs: references.kitIDs,
        knownSkillIDs: references.skillIDs
      )
      let validation = builder.validate(
        draft: draft,
        existingPersonaIDs: [],
        knownKitIDs: references.kitIDs,
        knownSkillIDs: references.skillIDs
      )

      let manager = WorkspaceLibraryEntityManager()
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .persona
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "persona",
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
          entityType: .persona
        )
      }
    }
  }
}
