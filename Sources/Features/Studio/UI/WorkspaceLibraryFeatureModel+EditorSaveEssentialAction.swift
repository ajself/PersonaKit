import ContextCore
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
}
