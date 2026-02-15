import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned session preview model used by `WorkspaceStore`.
@MainActor
final class WorkspaceSessionFeatureModel {
  private let operationRunner: WorkspaceOperationRunner
  private let previewExportDestinationPicker: any PreviewExportDestinationPicking
  private let pasteboardWriter: any PasteboardWriting

  private var previewTask: Task<Void, Never>?
  private var state = WorkspaceSessionPreviewState()
  private var activeWorkspaceURL: URL?

  init(
    operationRunner: WorkspaceOperationRunner,
    previewExportDestinationPicker: any PreviewExportDestinationPicking,
    pasteboardWriter: any PasteboardWriting
  ) {
    self.operationRunner = operationRunner
    self.previewExportDestinationPicker = previewExportDestinationPicker
    self.pasteboardWriter = pasteboardWriter
  }

  var preview: String {
    get {
      state.preview
    }

    set {
      state.setPreview(newValue)
    }
  }

  var previewErrorMessage: String? {
    state.errorMessage
  }

  var isLoadingPreview: Bool {
    state.isLoading
  }

  func refreshPreview(
    for session: WorkspaceSessionListItem?,
    workspaceURL: URL?
  ) {
    cancelPreviewTask()

    guard let session else {
      clearPreview()
      return
    }

    guard let workspaceURL else {
      clearPreview()
      return
    }

    activeWorkspaceURL = workspaceURL
    state.beginLoading(sessionID: session.id)

    previewTask = Task { [workspaceURL, session] in
      do {
        let preview = try await operationRunner.loadSessionPreview(
          workspaceURL: workspaceURL,
          session: session
        )

        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setLoadedPreview(preview)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setFailedPreview(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setFailedPreview(message: error.localizedDescription)
      }
    }
  }

  func restorePreviewIfPossible(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?
  ) {
    guard let previewSessionID = state.previewSessionID,
      let session = snapshot.sessions.first(where: { $0.id == previewSessionID })
    else {
      clearPreview()
      return
    }

    refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )
  }

  func copyPreviewToPasteboard() throws {
    guard !state.preview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No preview is available to copy."
      )
    }

    guard pasteboardWriter.writeString(state.preview) else {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to copy preview to the clipboard."
      )
    }
  }

  func exportPreviewWithSavePanel() async throws -> Bool {
    guard !state.preview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No preview is available to export."
      )
    }

    guard
      let destinationURL = previewExportDestinationPicker.pickPreviewDestination(
        suggestedFilename: state.defaultFilename()
      )
    else {
      return false
    }

    try await operationRunner.exportSessionPreview(
      state.preview,
      to: destinationURL
    )

    return true
  }

  func cancelPreviewTask() {
    previewTask?.cancel()
    previewTask = nil
  }

  func clearPreview() {
    cancelPreviewTask()
    activeWorkspaceURL = nil
    state.clear()
  }
}
