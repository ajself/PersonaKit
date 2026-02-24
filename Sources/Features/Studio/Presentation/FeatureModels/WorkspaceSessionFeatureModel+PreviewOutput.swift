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
}
