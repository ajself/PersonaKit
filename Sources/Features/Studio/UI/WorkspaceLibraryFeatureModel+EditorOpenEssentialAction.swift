import ContextCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Loads markdown for a selected project-scoped essential.
  func openEssentialEditor(
    selectedItem: WorkspaceListItem?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor () -> URL?
  ) async -> WorkspaceEssentialEditorPresentation? {
    guard let selectedItem else {
      return nil
    }

    guard selectedItem.sourceScope == .project else {
      setAction(
        message: "Global essentials are read-only. Use Copy to Project first.",
        isError: true
      )
      return nil
    }

    guard
      let projectEssential = WorkspaceSnapshotLookup.essentialItem(
        snapshot: snapshot,
        itemID: selectedItem.id
      ),
      projectEssential.sourceScope == .project,
      projectEssential.fileURL.standardizedFileURL == selectedItem.fileURL.standardizedFileURL
    else {
      setAction(
        message:
          "Selected item is not a project essential in the current snapshot. Reload the workspace and try again.",
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
      let markdown = try await operationRunner.loadEssentialMarkdown(fileURL: projectEssential.fileURL)

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return nil
      }

      return WorkspaceEssentialEditorPresentation(
        fileURL: projectEssential.fileURL.standardizedFileURL,
        itemID: projectEssential.id,
        markdown: markdown,
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
