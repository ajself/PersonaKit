import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned library editor and copy-flow model used by `WorkspaceStore`.
@MainActor
final class WorkspaceLibraryFeatureModel {
  private let operationRunner: WorkspaceOperationRunner
  private var state = WorkspaceLibraryActionState()

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
  }

  var actionMessage: String? {
    state.message
  }

  var actionIsError: Bool {
    state.isError
  }

  var isLoadingEditor: Bool {
    state.isLoadingEditor
  }

  func invalidateRequests() {
    state.invalidateRequests()
  }

  func resetState() {
    state.reset()
  }

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

  /// Copies a selected global library item into project scope and updates status state.
  func copySelectedGlobalLibraryItem(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> Bool {
    guard let selectedItem else {
      return false
    }

    guard let entityType else {
      setAction(
        message: "Raw JSON copy is not available for this category.",
        isError: true
      )
      return false
    }

    guard selectedItem.sourceScope == .global else {
      setAction(
        message: "Copy to Project is only available for global items.",
        isError: true
      )
      return false
    }

    guard
      let globalItem = WorkspaceSnapshotLookup.libraryItem(
        snapshot: snapshot,
        itemID: selectedItem.id,
        entityType: entityType
      ),
      globalItem.sourceScope == .global,
      globalItem.fileURL.standardizedFileURL == selectedItem.fileURL.standardizedFileURL
    else {
      setAction(
        message:
          "Selected item is not a global library entity in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return false
    }

    let requestID = beginRequest()
    let requestWorkspaceURL = workspaceURL

    do {
      let workspaceURL = try requiredWorkspaceURL(workspaceURL)

      try await operationRunner.copyLibraryItemToProject(
        workspaceURL: workspaceURL,
        item: globalItem,
        entityType: entityType
      )

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return false
      }

      setAction(
        message: "Copied \(globalItem.id) to project scope.",
        isError: false
      )

      onWorkspaceMutation()
      return true
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return false
      }

      setAction(
        message: error.localizedDescription,
        isError: true
      )
      return false
    }
  }

  /// Copies a selected global essential into project scope and updates status state.
  func copySelectedGlobalEssentialToProject(
    selectedItem: WorkspaceListItem?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor () -> URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async -> Bool {
    guard let selectedItem else {
      return false
    }

    guard selectedItem.sourceScope == .global else {
      setAction(
        message: "Copy to Project is only available for global essentials.",
        isError: true
      )
      return false
    }

    guard
      let globalEssential = WorkspaceSnapshotLookup.essentialItem(
        snapshot: snapshot,
        itemID: selectedItem.id
      ),
      globalEssential.sourceScope == .global,
      globalEssential.fileURL.standardizedFileURL == selectedItem.fileURL.standardizedFileURL
    else {
      setAction(
        message:
          "Selected item is not a global essential in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return false
    }

    let requestID = beginRequest()
    let requestWorkspaceURL = workspaceURL

    do {
      let workspaceURL = try requiredWorkspaceURL(workspaceURL)

      try await operationRunner.copyGlobalEssentialToProject(
        workspaceURL: workspaceURL,
        item: globalEssential
      )

      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return false
      }

      setAction(
        message: "Copied \(globalEssential.id) to project scope.",
        isError: false
      )

      onWorkspaceMutation()
      return true
    } catch {
      guard
        completeRequest(
          requestID: requestID,
          expectedWorkspaceURL: requestWorkspaceURL,
          currentWorkspaceURL: currentWorkspaceURL()
        )
      else {
        return false
      }

      setAction(
        message: error.localizedDescription,
        isError: true
      )
      return false
    }
  }

  private func beginRequest() -> Int {
    state.beginRequest()
  }

  private func completeRequest(
    requestID: Int,
    expectedWorkspaceURL: URL?,
    currentWorkspaceURL: URL?
  ) -> Bool {
    state.completeRequest(
      requestID: requestID,
      currentWorkspaceURL: currentWorkspaceURL,
      expectedWorkspaceURL: expectedWorkspaceURL
    )
  }

  private func requiredWorkspaceURL(_ workspaceURL: URL?) throws -> URL {
    guard let workspaceURL else {
      throw WorkspaceSnapshotBuildError(
        message: "No workspace is currently selected."
      )
    }

    return workspaceURL
  }

  private func setAction(
    message: String,
    isError: Bool
  ) {
    state.setAction(
      message: message,
      isError: isError
    )
  }
}
