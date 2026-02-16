import ContextCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Loads raw JSON for a selected project-scoped library item.
  func openLibraryEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor () -> URL?
  ) async -> WorkspaceLibraryEditorPresentation? {
    guard let selectedItem else {
      return nil
    }

    guard let entityType else {
      setAction(
        message: "Raw JSON editing is not available for this category.",
        isError: true
      )
      return nil
    }

    guard selectedItem.sourceScope == .project else {
      setAction(
        message: "Global items are read-only. Use Copy to Project first.",
        isError: true
      )
      return nil
    }

    guard
      let projectItem = WorkspaceSnapshotLookup.libraryItem(
        snapshot: snapshot,
        itemID: selectedItem.id,
        entityType: entityType
      ),
      projectItem.sourceScope == .project,
      projectItem.fileURL.standardizedFileURL == selectedItem.fileURL.standardizedFileURL
    else {
      setAction(
        message:
          "Selected item is not a project library entity in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return nil
    }

    guard let requestWorkspaceURL = workspaceURL?.standardizedFileURL else {
      setAction(
        message: "No workspace is currently selected.",
        isError: true
      )
      return nil
    }

    let requestID = beginRequest()

    do {
      let rawJSON = try await operationRunner.loadLibraryItemRawJSON(fileURL: projectItem.fileURL)

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return nil
      }

      return WorkspaceLibraryEditorPresentation(
        itemID: projectItem.id,
        entityType: entityType,
        fileURL: projectItem.fileURL.standardizedFileURL,
        rawJSON: rawJSON,
        workspaceURL: requestWorkspaceURL
      )
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return nil
      }

      setAction(
        message: error.localizedDescription,
        isError: true
      )

      return nil
    }
  }
}
