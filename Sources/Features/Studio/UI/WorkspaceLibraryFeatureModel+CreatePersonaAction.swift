import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Creates a default draft for new-persona creation.
  func defaultPersonaDraft() -> WorkspacePersonaDraft {
    WorkspacePersonaDraftBuilder().defaultDraft()
  }

  /// Saves a new persona draft and returns an optional error message.
  func createPersona(
    draft: WorkspacePersonaDraft,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURLProvider: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> String? {
    let draftBuilder = WorkspacePersonaDraftBuilder()
    let existingPersonaIDs = Set(snapshot.personas.map(\.id))
    let knownKitIDs = Set(snapshot.kits.map(\.id))
    let knownSkillIDs = Set(snapshot.skills.map(\.id))
    let validation = draftBuilder.validate(
      draft: draft,
      existingPersonaIDs: existingPersonaIDs,
      knownKitIDs: knownKitIDs,
      knownSkillIDs: knownSkillIDs
    )

    guard validation.errors.isEmpty else {
      let message = validation.errors.joined(separator: " ")

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    let normalizedDraft = draftBuilder.normalizedDraft(draft)
    let rawJSON: String

    do {
      rawJSON = try draftBuilder.buildRawJSON(
        draft: normalizedDraft,
        existingPersonaIDs: existingPersonaIDs,
        knownKitIDs: knownKitIDs,
        knownSkillIDs: knownSkillIDs
      )
    } catch {
      let message = error.localizedDescription

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    let requestWorkspaceURL = workspaceURL?.standardizedFileURL
    let requestID = beginRequest()

    do {
      let workspaceURL = try requiredWorkspaceURL(workspaceURL)

      try await operationRunner.saveLibraryItemRawJSON(
        workspaceURL: workspaceURL,
        itemID: normalizedDraft.id,
        rawJSON: rawJSON,
        entityType: .persona
      )

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      setAction(
        message: "Created \(normalizedDraft.id).",
        isError: false
      )

      onWorkspaceMutation()
      return nil
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      let message = error.localizedDescription

      setAction(
        message: message,
        isError: true
      )

      return message
    }
  }
}
