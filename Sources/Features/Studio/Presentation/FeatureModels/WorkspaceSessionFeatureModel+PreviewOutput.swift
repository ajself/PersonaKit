import ContextCore
import ContextWorkspaceCore

extension WorkspaceSessionFeatureModel {
  func copyPreviewToPasteboard() throws {
    guard !state.preview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No handoff context is available to copy."
      )
    }

    guard pasteboardWriter.writeString(state.preview) else {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to copy handoff context to the clipboard."
      )
    }
  }

  func exportPreviewWithSavePanel() async throws -> Bool {
    guard !state.preview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No handoff context is available to export."
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
      setPreviewActionMessage("Copied handoff context to clipboard.", isError: false)
    } catch {
      setPreviewActionMessage(error.localizedDescription, isError: true)
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

        if didExport {
          setPreviewActionMessage("Exported handoff context.", isError: false)
        } else {
          clearPreviewActionMessage()
        }
      } catch {
        guard !Task.isCancelled else {
          return
        }

        setPreviewActionMessage(error.localizedDescription, isError: true)
      }

      previewExportTask = nil
    }
  }

  func clearPreviewActionMessage() {
    previewActionMessage = nil
    previewActionIsError = false
  }

  private func setPreviewActionMessage(_ message: String, isError: Bool) {
    previewActionMessage = message
    previewActionIsError = isError
  }
}
