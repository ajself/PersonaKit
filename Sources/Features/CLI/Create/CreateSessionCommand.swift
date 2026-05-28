import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

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
