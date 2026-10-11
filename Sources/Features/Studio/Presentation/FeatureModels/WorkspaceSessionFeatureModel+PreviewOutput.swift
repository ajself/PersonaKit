import ContextCore
import ContextWorkspaceCore

extension WorkspaceSessionFeatureModel {
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

  /// Copies the preview and reports the outcome in ``previewActionMessage``.
  func copyPreviewReportingResult() {
    do {
      try copyPreviewToPasteboard()
      previewActionMessage = "Copied preview to clipboard."
    } catch {
      previewActionMessage = error.localizedDescription
    }
  }

  /// Runs the export flow in an owned task and reports the outcome in ``previewActionMessage``.
  func exportPreviewReportingResult() {
    previewExportTask?.cancel()
    previewExportTask = Task {
      do {
        let didExport = try await exportPreviewWithSavePanel()

        guard !Task.isCancelled else {
          return
        }

        previewActionMessage = didExport ? "Exported preview markdown." : nil
      } catch {
        guard !Task.isCancelled else {
          return
        }

        previewActionMessage = error.localizedDescription
      }

      previewExportTask = nil
    }
  }

  func clearPreviewActionMessage() {
    previewActionMessage = nil
  }
}
