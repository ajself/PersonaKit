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

  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    do {
      try await operationRunner.validateLibraryItemRawJSON(
        rawJSON,
        itemID: presentation.itemID,
        entityType: presentation.entityType
      )

      return nil
    } catch {
      return error.localizedDescription
    }
  }

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
}
