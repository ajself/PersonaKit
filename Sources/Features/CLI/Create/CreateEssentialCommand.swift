import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

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
