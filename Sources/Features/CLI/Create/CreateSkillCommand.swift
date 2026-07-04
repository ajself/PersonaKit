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

  @Option(name: .customLong("path-glob"), help: "Grounding trigger path glob (e.g. \"**/*.swift\").")
  var pathGlobs: [String] = []

  @Option(name: .customLong("skill-tag"), help: "Grounding trigger skill tag.")
  var skillTags: [String] = []

  @Flag(
    name: .customLong("always-on"),
    help: "Author an always-on grounding skill that applies to every session (emits the empty trigger rule)."
  )
  var alwaysOn = false

  @Option(name: .customLong("body"), help: "Grounding skill body markdown text.")
  var body: String?

  @Flag(name: .customLong("stdin-body"), help: "Read the grounding skill body from stdin.")
  var stdinBody = false

  func run() throws {
    try CreateCommandHelpers.runWithJSONErrors(jsonOutput: shared.jsonOutput) {
      if stdinBody, body != nil {
        throw CLIError.failure("--body and --stdin-body cannot be used together.")
      }

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

      // Grounding triggers are optional; a plain tool skill declares none. When
      // present, the skill also carries an expandable markdown body written
      // alongside the JSON at Packs/skills/<id>.md.
      var resolvedBody = CreateCommandHelpers.trimmed(body)
      if stdinBody {
        resolvedBody = CreateCommandHelpers.trimmed(try CLIEnvironment.current.interactiveIO.readStdinToEnd())
      }
      // Always-on skills ground every session unconditionally, so they are
      // grounding too (and carry an expandable body just like path/tag skills).
      let isGrounding = !pathGlobs.isEmpty || !skillTags.isEmpty || alwaysOn

      // A body only ever surfaces through a matching trigger, so a body supplied
      // without any --path-glob/--skill-tag/--always-on would be silently dropped.
      // Fail loudly instead (the folded former `create reference` enforced the same rule).
      if body != nil || stdinBody, !isGrounding {
        throw CLIError.failure(
          "A grounding-skill body requires at least one trigger. Add --path-glob, --skill-tag, or --always-on, "
            + "e.g. personakit create skill --name \"Swift Style\" --description \"...\" "
            + "--path-glob \"**/*.swift\" --body \"...\"."
        )
      }

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
        notes: resolvedNotes,
        pathGlobs: pathGlobs,
        skillTags: skillTags,
        alwaysOn: alwaysOn
      )
      let builder = WorkspaceSkillDraftBuilder()
      let rawJSON = try builder.buildRawJSON(draft: draft)
      let validation = builder.validate(draft: draft)
      let manager = WorkspaceLibraryEntityManager()
      let normalizedID = CreateCommandHelpers.normalizedID(draft.id)
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .skill
      )

      let bodyURL =
        destinationURL
        .deletingLastPathComponent()
        .appendingPathComponent("\(normalizedID).md")
      let markdown =
        isGrounding
        ? Self.buildGroundingMarkdown(
          title: resolvedName,
          body: resolvedBody.isEmpty ? resolvedDescription : resolvedBody,
          template: shared.resolvedTemplate
        )
        : nil

      // completeCreation only guards the JSON destination; the companion .md
      // body is a second file, so guard it here under the same --force contract
      // (and before any write) to avoid silently clobbering a hand-authored body.
      if markdown != nil, !shared.dryRun {
        _ = try CreateCommandHelpers.prepareWrite(destinationURL: bodyURL, force: shared.force)
      }

      try CreateCommandHelpers.completeCreation(
        entityType: "skill",
        entityID: normalizedID,
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
        if let markdown {
          try Data(markdown.utf8).write(to: bodyURL, options: [.atomic])
        }
      }
    }
  }

  /// Renders the expandable markdown body written alongside a grounding skill's JSON.
  private static func buildGroundingMarkdown(
    title: String,
    body: String?,
    template: WorkspaceCreationTemplate
  ) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)

    let defaultBody: String
    switch template {
    case .starter:
      defaultBody = "TODO: add grounding guidance."
    case .minimal:
      defaultBody = ""
    }

    var sections = ["# \(trimmedTitle)"]

    let finalBody = trimmedBody ?? defaultBody
    if !finalBody.isEmpty {
      sections.append(finalBody)
    }

    return sections.joined(separator: "\n\n") + "\n"
  }
}
