import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned session preview model used by `WorkspaceStore`.
@MainActor
final class WorkspaceSessionFeatureModel {
  let operationRunner: WorkspaceOperationRunner
  let previewExportDestinationPicker: any PreviewExportDestinationPicking
  let pasteboardWriter: any PasteboardWriting

  var previewTask: Task<Void, Never>?
  var state = WorkspaceSessionPreviewState()
  var activeWorkspaceURL: URL?

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
}
