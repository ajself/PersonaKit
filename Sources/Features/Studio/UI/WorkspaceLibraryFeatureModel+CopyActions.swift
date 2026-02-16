import ContextCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
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
}
