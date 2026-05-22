import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create PersonaKit entities and authored files.",
    subcommands: [
      CreatePersonaCommand.self,
      CreateKitCommand.self,
      CreateDirectiveCommand.self,
      CreateIntentCommand.self,
      CreateSkillCommand.self,
      CreateSessionCommand.self,
      CreateEssentialCommand.self,
    ]
  )
}

struct CreateSharedOptions: ParsableArguments {
  @Option(
    name: .customLong("root"),
    help: "Writable PersonaKit root. Defaults to the nearest project .personakit, then ~/.personakit.",
    completion: .directory
  )
  var rootPath: String?

  @Option(
    name: .customLong("template"),
    help: "Template preset to use."
  )
  var template: CreateTemplateOption = .starter

  @Flag(name: .customLong("dry-run"), help: "Render destination and content without writing.")
  var dryRun = false

  @Flag(name: .customLong("force"), help: "Overwrite an existing authored file.")
  var force = false

  @Flag(name: .customLong("json"), help: "Emit machine-readable success or error output.")
  var jsonOutput = false

  var resolvedTemplate: WorkspaceCreationTemplate {
    template.workspaceTemplate
  }
}

enum CreateTemplateOption: String, ExpressibleByArgument {
  case starter
  case minimal

  var workspaceTemplate: WorkspaceCreationTemplate {
    switch self {
    case .starter:
      return .starter
    case .minimal:
      return .minimal
    }
  }
}

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
        skillIds: resolvedSkillIDs
      )
      let builder = WorkspaceKitDraftBuilder()
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
        requiresSkillIds: resolvedSkillIDs
      )
      let builder = WorkspaceDirectiveDraftBuilder()
      let rawJSON = try builder.buildRawJSON(
        draft: draft,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs
      )
      let validation = builder.validate(
        draft: draft,
        knownIntentIDs: references.intentIDs,
        knownSkillIDs: references.skillIDs
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

  @Option(name: .customLong("provided-by"), help: "Provider description.")
  var providedBy: [String] = []

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

struct CreateSessionCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "session",
    abstract: "Create a session JSON document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Session id.")
  var id: String?

  @Option(name: .customLong("persona"), help: "Persona id.")
  var personaID: String?

  @Option(name: .customLong("directive"), help: "Directive id.")
  var directiveID: String?

  @Option(name: .customLong("kit-override"), help: "Kit override id.")
  var kitOverrideIDs: [String] = []

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let references = try CreateCommandHelpers.loadReferences(rootURL: rootURL)
      let prompter = CreatePrompter()

      var resolvedPersonaID = CreateCommandHelpers.normalizedID(personaID)
      if resolvedPersonaID.isEmpty, prompter.isInteractive {
        resolvedPersonaID = CreateCommandHelpers.normalizedID(
          prompter.promptRequired(
            "Persona id",
            hint: CreateCommandHelpers.referenceHint(
              label: "Known personas",
              values: references.personaIDs
            )
          )
        )
      }

      var resolvedDirectiveID = CreateCommandHelpers.normalizedID(directiveID)
      if resolvedDirectiveID.isEmpty, prompter.isInteractive {
        resolvedDirectiveID = CreateCommandHelpers.normalizedID(
          prompter.promptRequired(
            "Directive id",
            hint: CreateCommandHelpers.referenceHint(
              label: "Known directives",
              values: references.directiveIDs
            )
          )
        )
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty {
        resolvedID = WorkspaceSessionDraftBuilder.suggestedID(
          personaID: resolvedPersonaID,
          directiveID: resolvedDirectiveID
        )
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        let suggestion = WorkspaceSessionDraftBuilder.suggestedID(
          personaID: resolvedPersonaID,
          directiveID: resolvedDirectiveID
        )
        resolvedID = prompter.promptSuggestedExistingID(
          label: "Session id",
          suggestedID: suggestion
        )
      }

      let resolvedKitOverrides = prompter.promptCSVIfNeeded(
        values: kitOverrideIDs,
        label: "Kit override ids (comma-separated)",
        hint: CreateCommandHelpers.referenceHint(
          label: "Known kits",
          values: references.kitIDs
        )
      )

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id or --persona/--directive" : nil,
          resolvedPersonaID.isEmpty ? "--persona" : nil,
          resolvedDirectiveID.isEmpty ? "--directive" : nil,
        ],
        example:
          "personakit create session --persona senior-swiftui-engineer --directive apply-style",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceSessionDraft(
        id: resolvedID,
        personaId: resolvedPersonaID,
        directiveId: resolvedDirectiveID,
        kitOverrides: resolvedKitOverrides
      )
      let rawJSON = try WorkspaceSessionDraftBuilder.buildRawJSON(
        draft: draft,
        validPersonaIDs: references.personaIDs,
        validDirectiveIDs: references.directiveIDs,
        validKitIDs: references.kitIDs
      )
      let destinationURL = try WorkspaceSessionManager().destinationFileURL(
        workspaceURL: rootURL,
        sessionID: draft.id
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "session",
        entityID: CreateCommandHelpers.normalizedID(draft.id),
        destinationURL: destinationURL,
        warnings: [],
        renderedContent: rawJSON,
        dryRun: shared.dryRun,
        force: shared.force,
        jsonOutput: shared.jsonOutput,
        prompter: prompter
      ) {
        let originalSessionID = shared.force ? draft.id : nil
        _ = try WorkspaceSessionManager().saveSession(
          workspaceURL: rootURL,
          draft: draft,
          originalSessionID: originalSessionID,
          validPersonaIDs: references.personaIDs,
          validDirectiveIDs: references.directiveIDs,
          validKitIDs: references.kitIDs
        )
      }
    }
  }
}

struct CreateEssentialCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "essential",
    abstract: "Create an essential markdown document."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Essential id.")
  var id: String?

  @Option(name: .customLong("title"), help: "Essential title.")
  var title: String?

  @Option(name: .customLong("body"), help: "Essential body text.")
  var body: String?

  @Flag(name: .customLong("stdin-body"), help: "Read the essential body from stdin.")
  var stdinBody = false

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      if stdinBody, body != nil {
        throw CLIError.failure("--body and --stdin-body cannot be used together.")
      }

      let rootURL = try CreateCommandHelpers.resolveWritableRoot(rootPath: shared.rootPath)
      let prompter = CreatePrompter()

      var resolvedTitle = CreateCommandHelpers.trimmed(title)
      if resolvedTitle.isEmpty, prompter.isInteractive {
        resolvedTitle = prompter.promptRequired("Essential title")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedTitle.isEmpty {
        resolvedID = WorkspaceEssentialDraftBuilder.suggestedID(from: resolvedTitle)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Essential id", source: resolvedTitle)
      }

      var resolvedBody = CreateCommandHelpers.trimmed(body)
      if stdinBody {
        resolvedBody = CreateCommandHelpers.trimmed(try CLIEnvironment.current.interactiveIO.readStdinToEnd())
      }
      if resolvedBody.isEmpty, prompter.isInteractive, !stdinBody {
        resolvedBody = prompter.promptOptional("Essential body")
      }

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id/--title" : nil,
          resolvedTitle.isEmpty ? "--title" : nil,
        ],
        example:
          "personakit create essential --title \"Planning Guardrails\" --body \"Keep milestone slices honest.\"",
        interactive: prompter.isInteractive
      )

      let markdown = WorkspaceEssentialDraftBuilder.buildMarkdown(
        title: resolvedTitle,
        body: resolvedBody.isEmpty ? nil : resolvedBody,
        template: shared.resolvedTemplate
      )
      let destinationURL = try WorkspaceEssentialManager().destinationFileURL(
        workspaceURL: rootURL,
        itemID: resolvedID
      )
      try CreateCommandHelpers.completeCreation(
        entityType: "essential",
        entityID: CreateCommandHelpers.normalizedID(resolvedID),
        destinationURL: destinationURL,
        warnings: [],
        renderedContent: markdown,
        dryRun: shared.dryRun,
        force: shared.force,
        jsonOutput: shared.jsonOutput,
        prompter: prompter
      ) {
        try WorkspaceEssentialManager().saveMarkdown(
          workspaceURL: rootURL,
          itemID: resolvedID,
          markdown: markdown
        )
      }
    }
  }
}

private struct CreateReferenceData {
  let personaIDs: Set<String>
  let directiveIDs: Set<String>
  let kitIDs: Set<String>
  let skillIDs: Set<String>
  let intentIDs: Set<String>
  let essentialIDs: Set<String>
}

private struct CreateResultEnvelope: Encodable {
  let result: WorkspaceCreationResult
  let renderedContent: String?
}

private struct CreateFailureEnvelope: Encodable {
  let error: String
}

private struct CreatePrompter {
  private let io: CLIInteractiveIO

  init(io: CLIInteractiveIO = CLIEnvironment.current.interactiveIO) {
    self.io = io
  }

  var isInteractive: Bool {
    io.isInteractive()
  }

  func promptRequired(
    _ label: String,
    hint: String? = nil
  ) -> String {
    while true {
      let value = promptOptional(label, hint: hint)
      if !value.isEmpty {
        return value
      }
    }
  }

  func promptOptional(
    _ label: String,
    hint: String? = nil
  ) -> String {
    if let hint {
      print(hint)
    }
    CreateCommandHelpers.writePrompt("\(label): ")
    return CreateCommandHelpers.trimmed(io.readLine())
  }

  func promptSuggestedID(
    label: String,
    source: String
  ) -> String {
    let suggested = WorkspaceEntityIDSuggester.suggestedID(from: source)
    if !suggested.isEmpty {
      print("Suggested id: \(suggested)")
    }
    CreateCommandHelpers.writePrompt("\(label)\(suggested.isEmpty ? "" : " [\(suggested)]"): ")
    let response = CreateCommandHelpers.normalizedID(io.readLine())
    return response.isEmpty ? suggested : response
  }

  func promptSuggestedExistingID(
    label: String,
    suggestedID: String
  ) -> String {
    if !suggestedID.isEmpty {
      print("Suggested id: \(suggestedID)")
    }
    CreateCommandHelpers.writePrompt("\(label)\(suggestedID.isEmpty ? "" : " [\(suggestedID)]"): ")
    let response = CreateCommandHelpers.normalizedID(io.readLine())
    return response.isEmpty ? suggestedID : response
  }

  func promptCSVIfNeeded(
    values: [String],
    label: String,
    hint: String?
  ) -> [String] {
    let existing = CreateCommandHelpers.trimmedItems(values)
    guard existing.isEmpty, isInteractive else {
      return existing
    }

    let response = promptOptional(label, hint: hint)
    return CreateCommandHelpers.parseCSV(response)
  }

  func promptRepeatedText(_ label: String) -> [String] {
    guard isInteractive else {
      return []
    }

    var values: [String] = []

    while true {
      CreateCommandHelpers.writePrompt("\(label) (blank to finish): ")
      let value = CreateCommandHelpers.trimmed(io.readLine())

      if value.isEmpty {
        break
      }

      values.append(value)
    }

    return values
  }

  func promptYesNo(
    label: String,
    defaultValue: Bool
  ) -> Bool {
    guard isInteractive else {
      return defaultValue
    }

    while true {
      let suffix = defaultValue ? "[Y/n]" : "[y/N]"
      CreateCommandHelpers.writePrompt("\(label) \(suffix): ")
      let response = CreateCommandHelpers.trimmed(io.readLine()).lowercased()

      if response.isEmpty {
        return defaultValue
      }

      switch response {
      case "y", "yes":
        return true
      case "n", "no":
        return false
      default:
        continue
      }
    }
  }

  func promptRiskLevel(defaultValue: String) throws -> String {
    while true {
      CreateCommandHelpers.writePrompt("Risk level [\(defaultValue)] (low|medium|high): ")
      let response = CreateCommandHelpers.trimmed(io.readLine())
      let value = response.isEmpty ? defaultValue : response

      do {
        try CreateCommandHelpers.validateRiskLevel(value)
        return value
      } catch {
        continue
      }
    }
  }

  func confirmWrite(
    entityType: String,
    entityID: String,
    destinationURL: URL,
    force: Bool
  ) throws {
    guard isInteractive else {
      return
    }

    print("Ready to create \(entityType) \"\(entityID)\" at \(destinationURL.path)")
    if force {
      print("Existing file will be overwritten if present.")
    }

    guard promptYesNo(label: "Write file now", defaultValue: true) else {
      throw CleanExit.message("Creation cancelled.")
    }
  }
}

private enum CreateCommandHelpers {
  static func runWithJSONErrors(
    jsonOutput: Bool,
    _ body: () throws -> Void
  ) throws {
    do {
      try body()
    } catch let error as CleanExit {
      throw error
    } catch {
      if jsonOutput {
        emitJSON(CreateFailureEnvelope(error: errorMessage(for: error)))
        throw ExitCode.failure
      }

      throw error
    }
  }

  static func errorMessage(for error: Error) -> String {
    if let validationError = error as? ArgumentParser.ValidationError {
      return validationError.message
    }

    if let localizedError = error as? LocalizedError,
      let errorDescription = localizedError.errorDescription
    {
      return errorDescription
    }

    return error.localizedDescription
  }

  static func resolveWritableRoot(rootPath: String?) throws -> URL {
    do {
      let explicitRootURL = rootPath.map { RootPathResolver().resolve(path: $0) }
      return try WorkspaceWritableRootResolver(
        scopeRootResolver: CLIEnvironment.current.scopeRootResolver
      )
      .resolveWritableRoot(explicitRootURL: explicitRootURL)
    } catch let error as WorkspaceSnapshotBuildError {
      throw ArgumentParser.ValidationError(error.message)
    }
  }

  static func loadReferences(rootURL: URL) throws -> CreateReferenceData {
    let scopes = resolveReferenceScopes(for: rootURL)

    let registry: Registry
    do {
      registry = try Registry.load(scopes: scopes)
    } catch let error as RegistryLoadError {
      let details = error.errors.map(CLIHelpers.formatRegistryError).joined(separator: "\n")
      throw CLIError.failure(details)
    }

    let essentials = try discoverEssentialIDs(rootURL: rootURL)
    return CreateReferenceData(
      personaIDs: Set(registry.personas.map(\.id)),
      directiveIDs: Set(registry.directives.map(\.id)),
      kitIDs: Set(registry.kits.map(\.id)),
      skillIDs: Set(registry.skills.map(\.id)),
      intentIDs: Set(registry.intentTemplates.map(\.id)),
      essentialIDs: essentials
    )
  }

  static func requireFields(
    _ fields: [String?],
    example: String,
    interactive: Bool
  ) throws {
    let missing = fields.compactMap { $0 }

    guard !missing.isEmpty else {
      return
    }

    guard !interactive else {
      throw CLIError.failure("Missing required fields: \(missing.joined(separator: ", ")).")
    }

    throw ArgumentParser.ValidationError(
      "Missing required fields: \(missing.joined(separator: ", ")). Example: \(example)"
    )
  }

  static func prepareWrite(
    destinationURL: URL,
    force: Bool
  ) throws -> Bool {
    let exists = FileManager.default.fileExists(atPath: destinationURL.path)

    if exists, !force {
      throw CLIError.failure(
        "Refusing to overwrite existing file: \(destinationURL.path). Use --force to overwrite."
      )
    }

    return exists
  }

  static func completeCreation(
    entityType: String,
    entityID: String,
    destinationURL: URL,
    warnings: [String],
    renderedContent: String,
    dryRun: Bool,
    force: Bool,
    jsonOutput: Bool,
    prompter: CreatePrompter,
    writeAction: () throws -> Void
  ) throws {
    let overwrote = FileManager.default.fileExists(atPath: destinationURL.path)

    if !dryRun {
      _ = try prepareWrite(
        destinationURL: destinationURL,
        force: force
      )

      try prompter.confirmWrite(
        entityType: entityType,
        entityID: entityID,
        destinationURL: destinationURL,
        force: force
      )

      try writeAction()
    }

    let result = WorkspaceCreationResult(
      entityType: entityType,
      entityID: entityID,
      destinationPath: destinationURL.path,
      warnings: warnings,
      overwroteExisting: overwrote,
      dryRun: dryRun
    )
    emitSuccess(
      result: result,
      renderedContent: dryRun ? renderedContent : nil,
      jsonOutput: jsonOutput
    )
  }

  static func emitSuccess(
    result: WorkspaceCreationResult,
    renderedContent: String?,
    jsonOutput: Bool
  ) {
    if jsonOutput {
      emitJSON(
        CreateResultEnvelope(
          result: result,
          renderedContent: renderedContent
        )
      )
      return
    }

    if result.dryRun {
      print("Dry run for \(result.entityType) \"\(result.entityID)\"")
      print("Destination: \(result.destinationPath)")
      if !result.warnings.isEmpty {
        for warning in result.warnings {
          print("Warning: \(warning)")
        }
      }
      if let renderedContent {
        print("")
        print(renderedContent, terminator: "")
      }
      return
    }

    print("Created \(result.entityType) \"\(result.entityID)\" at \(result.destinationPath)")
    if result.overwroteExisting {
      print("Overwrote existing file.")
    }
    for warning in result.warnings {
      print("Warning: \(warning)")
    }
    if let rootPath = inferredRootPath(fromDestinationPath: result.destinationPath) {
      print("Next: personakit validate --root \(rootPath)")
    }
  }

  static func emitJSON<T: Encodable>(_ value: T) {
    do {
      print(try WorkspaceAuthoringJSON.encode(value), terminator: "")
    } catch {
      var stderrStream = StandardError()
      stderrStream.write("Error: \(error.localizedDescription)\n")
    }
  }

  static func referenceHint(
    label: String,
    values: Set<String>
  ) -> String? {
    guard !values.isEmpty else {
      return nil
    }

    let sorted = values.sorted()
    let preview = sorted.prefix(8).joined(separator: ", ")

    if sorted.count > 8 {
      return "\(label): \(preview), ..."
    }

    return "\(label): \(preview)"
  }

  static func parseIntentParameter(_ spec: String) throws -> IntentTemplate.Parameter {
    let trimmed = trimmed(spec)
    let components = trimmed.split(separator: ":", omittingEmptySubsequences: false)

    guard components.count == 2 || components.count == 3 else {
      throw CLIError.failure(
        "Invalid parameter \"\(spec)\". Use name:type[:required]."
      )
    }

    let name = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
    let type = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)

    guard !name.isEmpty, !type.isEmpty else {
      throw CLIError.failure(
        "Invalid parameter \"\(spec)\". Use name:type[:required]."
      )
    }

    let required: Bool
    if components.count == 3 {
      let flag = String(components[2]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      switch flag {
      case "required", "true", "yes":
        required = true
      case "", "optional", "false", "no":
        required = false
      default:
        throw CLIError.failure(
          "Invalid parameter \"\(spec)\". Third component must be \"required\" when present."
        )
      }
    } else {
      required = false
    }

    return IntentTemplate.Parameter(name: name, type: type, required: required)
  }

  static func validateRiskLevel(_ value: String) throws {
    let normalized = trimmed(value).lowercased()

    switch normalized {
    case "low", "medium", "high":
      return
    default:
      throw CLIError.failure("Risk level must be one of: low, medium, high.")
    }
  }

  static func parseCSV(_ value: String?) -> [String] {
    guard let value else {
      return []
    }

    return
      value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  static func trimmed(_ value: String?) -> String {
    value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  static func trimmedItems(_ values: [String]) -> [String] {
    values
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  static func normalizedID(_ value: String?) -> String {
    let trimmed = trimmed(value)

    guard !trimmed.isEmpty else {
      return ""
    }

    return WorkspaceEntityIDPolicy.normalized(trimmed)
  }

  static func writePrompt(_ value: String) {
    guard let data = value.data(using: .utf8) else {
      return
    }

    FileHandle.standardOutput.write(data)
  }

  static func inferredRootPath(fromDestinationPath path: String) -> String? {
    let fileURL = URL(fileURLWithPath: path)
    let parent = fileURL.deletingLastPathComponent()

    if parent.lastPathComponent == "Sessions" {
      return parent.deletingLastPathComponent().path
    }

    if parent.deletingLastPathComponent().lastPathComponent == "Packs" {
      return parent.deletingLastPathComponent().deletingLastPathComponent().path
    }

    return nil
  }

  private static func discoverEssentialIDs(rootURL: URL) throws -> Set<String> {
    let essentialsDirectory = rootURL.appendingPathComponent("Packs/essentials")
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: essentialsDirectory.path, isDirectory: &isDirectory) else {
      return []
    }

    guard isDirectory.boolValue else {
      throw CLIError.failure("Essentials path is not a directory: \(essentialsDirectory.path)")
    }

    let files = try FileManager.default.contentsOfDirectory(
      at: essentialsDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )

    return Set(
      files
        .filter { $0.lastPathComponent.hasSuffix(".md") }
        .map { $0.deletingPathExtension().lastPathComponent }
    )
    .union(builtInEssentialIDs)
  }

  private static func resolveReferenceScopes(
    for rootURL: URL
  ) -> ScopeSet {
    let standardizedRootURL = rootURL.standardizedFileURL
    let discovered = CLIEnvironment.current.scopeRootResolver.locate()

    if discovered?.globalScopeURL?.standardizedFileURL == standardizedRootURL {
      return ScopeSet(projectScopeURL: nil, globalScopeURL: standardizedRootURL)
    }

    let globalScopeURL = discovered?.globalScopeURL?.standardizedFileURL

    return ScopeSet(
      projectScopeURL: standardizedRootURL,
      globalScopeURL: globalScopeURL == standardizedRootURL ? nil : globalScopeURL
    )
  }

  private static let builtInEssentialIDs: Set<String> = [
    "persona-activation-contract",
    "skill-authorization-contract",
  ]
}
