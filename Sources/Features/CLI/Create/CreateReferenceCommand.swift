import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateReferenceCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reference",
    abstract: "Create a reference JSON document and its markdown body."
  )

  @OptionGroup
  var shared: CreateSharedOptions

  @Option(name: .customLong("id"), help: "Reference id.")
  var id: String?

  @Option(name: .customLong("name"), help: "Reference name.")
  var name: String?

  @Option(name: .customLong("summary"), help: "Reference summary.")
  var summary: String?

  @Option(name: .customLong("path-glob"), help: "Trigger path glob (e.g. \"**/*.swift\").")
  var pathGlobs: [String] = []

  @Option(name: .customLong("reference-tag"), help: "Trigger reference tag.")
  var referenceTags: [String] = []

  @Option(name: .customLong("body"), help: "Reference body markdown text.")
  var body: String?

  @Flag(name: .customLong("stdin-body"), help: "Read the reference body from stdin.")
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
        resolvedName = prompter.promptRequired("Reference name")
      }

      var resolvedID = CreateCommandHelpers.normalizedID(id)
      if resolvedID.isEmpty, !resolvedName.isEmpty {
        resolvedID = WorkspaceEntityIDSuggester.suggestedID(from: resolvedName)
      }
      if resolvedID.isEmpty, prompter.isInteractive {
        resolvedID = prompter.promptSuggestedID(label: "Reference id", source: resolvedName)
      }

      var resolvedSummary = CreateCommandHelpers.trimmed(summary)
      if resolvedSummary.isEmpty, prompter.isInteractive {
        resolvedSummary = prompter.promptRequired("Reference summary")
      }

      let resolvedPathGlobs = prompter.promptCSVIfNeeded(
        values: pathGlobs,
        label: "Trigger path globs (comma-separated)",
        hint: nil
      )
      let resolvedReferenceTags = prompter.promptCSVIfNeeded(
        values: referenceTags,
        label: "Trigger reference tags (comma-separated)",
        hint: nil
      )

      var resolvedBody = CreateCommandHelpers.trimmed(body)
      if stdinBody {
        resolvedBody = CreateCommandHelpers.trimmed(try CLIEnvironment.current.interactiveIO.readStdinToEnd())
      }
      if resolvedBody.isEmpty, prompter.isInteractive, !stdinBody {
        resolvedBody = prompter.promptOptional("Reference body")
      }

      try CreateCommandHelpers.requireFields(
        [
          resolvedID.isEmpty ? "--id/--name" : nil,
          resolvedName.isEmpty ? "--name" : nil,
          resolvedSummary.isEmpty ? "--summary" : nil,
          resolvedPathGlobs.isEmpty && resolvedReferenceTags.isEmpty ? "--path-glob/--reference-tag" : nil,
        ],
        example:
          "personakit create reference --name \"Swift Style Guide\" --summary \"Deeper Swift style rationale.\" --path-glob \"**/*.swift\"",
        interactive: prompter.isInteractive
      )

      let draft = WorkspaceReferenceDraft(
        id: resolvedID,
        name: resolvedName,
        summary: resolvedSummary,
        pathGlobs: resolvedPathGlobs,
        referenceTags: resolvedReferenceTags
      )
      let builder = WorkspaceReferenceDraftBuilder()
      let rawJSON = try builder.buildRawJSON(draft: draft)
      let validation = builder.validate(draft: draft)
      let markdown = WorkspaceEssentialDraftBuilder.buildMarkdown(
        title: resolvedName,
        body: resolvedBody.isEmpty ? resolvedSummary : resolvedBody,
        template: shared.resolvedTemplate
      )
      let manager = WorkspaceLibraryEntityManager()
      let normalizedID = CreateCommandHelpers.normalizedID(draft.id)
      let destinationURL = try manager.destinationFileURL(
        workspaceURL: rootURL,
        itemID: draft.id,
        entityType: .reference
      )
      let bodyURL =
        destinationURL
        .deletingLastPathComponent()
        .appendingPathComponent("\(normalizedID).md")

      // completeCreation only guards the JSON destination; the companion .md
      // body is a second file, so guard it here under the same --force contract
      // (and before any write) to avoid silently clobbering a hand-authored body.
      if !shared.dryRun {
        _ = try CreateCommandHelpers.prepareWrite(destinationURL: bodyURL, force: shared.force)
      }

      try CreateCommandHelpers.completeCreation(
        entityType: "reference",
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
          entityType: .reference
        )
        try Data(markdown.utf8).write(to: bodyURL, options: [.atomic])
      }
    }
  }
}
