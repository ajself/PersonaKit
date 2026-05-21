import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Saves raw JSON from the library editor and returns an optional error message.
  func saveLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation,
    snapshot: WorkspaceSnapshot,
    currentWorkspaceURLProvider: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> String? {
    guard let currentWorkspaceURL = currentWorkspaceURLProvider() else {
      let message = "No workspace is currently selected."

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    let standardizedCurrentWorkspaceURL = currentWorkspaceURL.standardizedFileURL

    guard standardizedCurrentWorkspaceURL == presentation.workspaceURL.standardizedFileURL else {
      let message =
        "Workspace changed while this editor was open. Close and reopen the editor before saving."

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    if presentation.isCreatingNewItem {
      return await saveNewLibraryEditorRawJSON(
        rawJSON,
        presentation: presentation,
        snapshot: snapshot,
        currentWorkspaceURL: standardizedCurrentWorkspaceURL,
        currentWorkspaceURLProvider: currentWorkspaceURLProvider,
        onWorkspaceMutation: onWorkspaceMutation
      )
    }

    guard
      let projectItem = WorkspaceSnapshotLookup.projectLibraryItem(
        snapshot: snapshot,
        itemID: presentation.itemID,
        entityType: presentation.entityType
      ),
      projectItem.fileURL.standardizedFileURL == presentation.fileURL.standardizedFileURL
    else {
      let message =
        "Selected item is not available in project scope. Reload the workspace and try again."

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    let requestID = beginRequest()

    do {
      try await operationRunner.saveLibraryItemRawJSON(
        workspaceURL: standardizedCurrentWorkspaceURL,
        itemID: projectItem.id,
        rawJSON: rawJSON,
        entityType: presentation.entityType
      )

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: standardizedCurrentWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      setAction(
        message: "Saved \(projectItem.id).",
        isError: false
      )

      onWorkspaceMutation()
      return nil
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: standardizedCurrentWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      setAction(
        message: error.localizedDescription,
        isError: true
      )

      return error.localizedDescription
    }
  }

  private func saveNewLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation,
    snapshot: WorkspaceSnapshot,
    currentWorkspaceURL: URL,
    currentWorkspaceURLProvider: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> String? {
    let newItemID: String

    do {
      newItemID = try WorkspaceLibraryCreateSupport.validateNewLibraryItem(
        rawJSON: rawJSON,
        entityType: presentation.entityType
      )
    } catch {
      setAction(
        message: error.localizedDescription,
        isError: true
      )
      return error.localizedDescription
    }

    guard
      WorkspaceSnapshotLookup.libraryItem(
        snapshot: snapshot,
        itemID: newItemID,
        entityType: presentation.entityType
      ) == nil
    else {
      let message =
        "\(presentation.entityType.displayName) id \"\(newItemID)\" already exists."

      setAction(
        message: message,
        isError: true
      )
      return message
    }

    let requestID = beginRequest()

    do {
      try await operationRunner.saveLibraryItemRawJSON(
        workspaceURL: currentWorkspaceURL,
        itemID: newItemID,
        rawJSON: rawJSON,
        entityType: presentation.entityType
      )

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: currentWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      setAction(
        message: "Created \(newItemID).",
        isError: false
      )

      onWorkspaceMutation()
      return nil
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: currentWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURLProvider()
        )
      else {
        return nil
      }

      setAction(
        message: error.localizedDescription,
        isError: true
      )

      return error.localizedDescription
    }
  }
}
