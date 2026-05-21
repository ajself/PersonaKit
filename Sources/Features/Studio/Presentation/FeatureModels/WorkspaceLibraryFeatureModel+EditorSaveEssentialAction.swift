import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Saves markdown from the essentials editor and returns an optional error message.
  func saveEssentialEditorMarkdown(
    _ markdown: String,
    presentation: WorkspaceEssentialEditorPresentation,
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
      return await saveNewEssentialMarkdown(
        markdown,
        snapshot: snapshot,
        currentWorkspaceURL: standardizedCurrentWorkspaceURL,
        currentWorkspaceURLProvider: currentWorkspaceURLProvider,
        onWorkspaceMutation: onWorkspaceMutation
      )
    }

    guard
      let projectEssential = WorkspaceSnapshotLookup.projectEssentialItem(
        snapshot: snapshot,
        itemID: presentation.itemID
      ),
      projectEssential.fileURL.standardizedFileURL == presentation.fileURL.standardizedFileURL
    else {
      let message =
        "Selected essential is not available in project scope. Reload the workspace and try again."

      setAction(
        message: message,
        isError: true
      )

      return message
    }

    let requestID = beginRequest()

    do {
      try await operationRunner.saveEssentialMarkdown(
        workspaceURL: standardizedCurrentWorkspaceURL,
        itemID: projectEssential.id,
        markdown: markdown
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
        message: "Saved \(projectEssential.id).",
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

  private func saveNewEssentialMarkdown(
    _ markdown: String,
    snapshot: WorkspaceSnapshot,
    currentWorkspaceURL: URL,
    currentWorkspaceURLProvider: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> String? {
    let newItemID = WorkspaceLibraryCreateSupport.essentialItemID(markdown: markdown)

    guard !newItemID.isEmpty else {
      let message = "Essential title is required before saving."

      setAction(
        message: message,
        isError: true
      )
      return message
    }

    guard WorkspaceSnapshotLookup.essentialItem(snapshot: snapshot, itemID: newItemID) == nil else {
      let message = "Essential id \"\(newItemID)\" already exists."

      setAction(
        message: message,
        isError: true
      )
      return message
    }

    let requestID = beginRequest()

    do {
      try await operationRunner.saveEssentialMarkdown(
        workspaceURL: currentWorkspaceURL,
        itemID: newItemID,
        markdown: markdown
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
