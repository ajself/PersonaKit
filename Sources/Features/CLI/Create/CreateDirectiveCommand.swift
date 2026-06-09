import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateDirectiveCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "directive",
    abstract: "Create a directive JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Directive id.")
  var id: String?

  @Option(name: .customLong("title"), help: "Directive title.")
  var title: String?

  @Option(name: .customLong("goal"), help: "Directive goal.")
  var goal: String?

  @Option(name: .customLong("step"), help: "Normal step text.")
  var steps: [String] = []

  @Option(name: .customLong("review-step"), help: "Review-gated step text.")
  var reviewSteps: [String] = []

  @Option(name: .customLong("acceptance"), help: "Acceptance criteria item.")
  var acceptanceCriteria: [String] = []

  @Option(name: .customLong("verify-command"), help: "Verification command entry.")
  var verifyCommands: [String] = []

  @Option(name: .customLong("verify-manual"), help: "Verification manual entry.")
  var verifyManual: [String] = []

  @Option(name: .customLong("intent"), help: "Required intent id.")
  var intentIDs: [String] = []

  @Option(name: .customLong("skill"), help: "Required skill id.")
  var skillIDs: [String] = []

  @Option(name: .customLong("reference"), help: "Attached reference id.")
  var referenceIDs: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let references = try CreateCommandHelpers.loadReferences(rootURL: rootURL)
      let prompter = CreatePrompter()

      var resolvedTitle = CreateCommandHelpers.trimmed(title)
      if resolvedTitle.isEmpty, prompter.isInteractive {
        resolvedTitle = prompter.promptRequired("Directive title")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedTitle.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedTitle)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Directive id", source: resolvedTitle)
      }

      var resolvedGoal = CreateCommandHelpers.trimmed(goal)
      if resolvedGoal.isEmpty, prompter.isInteractive {
        resolvedGoal = prompter.promptRequired("Directive goal")
      }

      var resolvedSteps = CreateCommandHelpers.trimmedItems(steps).map {
        Directive.Step(text: $0, requiresReview: nil)
      }
      var resolvedReviewSteps = CreateCommandHelpers.trimmedItems(reviewSteps).map {
        Directive.Step(text: $0, requiresReview: true)
      }
      if prompter.isInteractive, resolvedSteps.isEmpty {
        resolvedSteps = prompter.promptRepeatedText("Step")
          .map { Directive.Step(text: $0, requiresReview: nil) }
      }
      if prompter.isInteractive, resolvedReviewSteps.isEmpty {
        resolvedReviewSteps = prompter.promptRepeatedText("Review step")
          .map { Directive.Step(text: $0, requiresReview: true) }
      }

      var resolvedAcceptance = CreateCommandHelpers.trimmedItems(acceptanceCriteria)
      if prompter.isInteractive, resolvedAcceptance.isEmpty {
        resolvedAcceptance = prompter.promptRepeatedText("Acceptance criteria")
      }

      var resolvedVerifyCommands = CreateCommandHelpers.trimmedItems(verifyCommands).map {
        Directive.VerificationItem(kind: "command", text: $0)
      }
      var resolvedVerifyManual = CreateCommandHelpers.trimmedItems(verifyManual).map {
        Directive.VerificationItem(kind: "manual", text: $0)
      }
      if prompter.isInteractive, resolvedVerifyCommands.isEmpty {
        resolvedVerifyCommands = prompter.promptRepeatedText("Verify command")
          .map { Directive.VerificationItem(kind: "command", text: $0) }
      }
      if prompter.isInteractive, resolvedVerifyManual.isEmpty {
        resolvedVerifyManual = prompter.promptRepeatedText("Verify manual")
          .map { Directive.VerificationItem(kind: "manual", text: $0) }
      }

      let defaultDraft = WorkspaceDirectiveDraftBuilder().defaultDraft(template: shared.resolvedTemplate)
      let combinedSteps = resolvedSteps + resolvedReviewSteps
      let finalSteps = combinedSteps.isEmpty ? defaultDraft.steps : combinedSteps
      let finalAcceptance = resolvedAcceptance.isEmpty ? defaultDraft.acceptanceCriteria : resolvedAcceptance
      let finalVerification =
        (resolvedVerifyCommands + resolvedVerifyManual).isEmpty
        ? defaultDraft.verification
        : (resolvedVerifyCommands + resolvedVerifyManual)
      let resolvedIntentIDs = prompter.promptCSVIfNeeded(
        values: intentIDs,
        label: "Required intent ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known intents",
          values: references.intentIDs
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
      let resolvedReferenceIDs = prompter.promptCSVIfNeeded(
        values: referenceIDs,
        label: "Attached reference ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known references",
          values: references.referenceIDs
        )
      )

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id/--title" : nil,
          resolvedTitle.isEmpty ? "--title" : nil,
          resolvedGoal.isEmpty ? "--goal" : nil,
        ],
        example:
          "personakit create directive --title \"Apply Style\" --goal \"Apply the repo style contract.\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceDirectiveDraft(
        id: resolvedID,
        title: resolvedTitle,
        goal: resolvedGoal,
        steps: finalSteps,
        acceptanceCriteria: finalAcceptance,
        verification: finalVerification,
        requiresIntentTemplateIds: resolvedIntentIDs,
        requiresSkillIds: resolvedSkillIDs,
        referenceIds: resolvedReferenceIDs
      )
      let builder = WorkspaceDirectiveDraftBuilder()
      let rawJSON = try builder.buildRawJSON(
        draft: draft,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs,
        knownReferenceIDs: references.referenceIDs
      )
      let validation = builder.validate(
        draft: draft,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs,
        knownReferenceIDs: references.referenceIDs
      )
      let manager = WorkspaceLibraryEntityManager()
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .directive
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "directive",
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
          entityType: .directive
        )
      }
    }
  }
}
