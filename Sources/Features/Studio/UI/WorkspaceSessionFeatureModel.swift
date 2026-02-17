import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned session preview model used by `WorkspaceStore`.
@Observable
@MainActor
final class WorkspaceSessionFeatureModel {
  let operationRunner: WorkspaceOperationRunner
  let previewExportDestinationPicker: any PreviewExportDestinationPicking
  let pasteboardWriter: any PasteboardWriting

  var previewTask: Task<Void, Never>?
  var mapTask: Task<Void, Never>?
  var draftMapTask: Task<Void, Never>?
  var workspaceRelationshipMapTask: Task<Void, Never>?
  var state = WorkspaceSessionPreviewState()
  var mapState = WorkspaceSessionMapState()
  var draftMapState = WorkspaceSessionMapState()
  var workspaceRelationshipMapState = WorkspaceSessionMapState()
  var activeWorkspaceURL: URL?
  var activeMapWorkspaceURL: URL?
  var activeDraftMapWorkspaceURL: URL?
  var activeWorkspaceRelationshipMapURL: URL?

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

  var map: WorkspaceSessionMap? {
    mapState.map
  }

  var mapErrorMessage: String? {
    mapState.errorMessage
  }

  var isLoadingMap: Bool {
    mapState.isLoading
  }

  var draftMap: WorkspaceSessionMap? {
    draftMapState.map
  }

  var draftMapErrorMessage: String? {
    draftMapState.errorMessage
  }

  var isLoadingDraftMap: Bool {
    draftMapState.isLoading
  }

  var workspaceRelationshipMap: WorkspaceSessionMap? {
    workspaceRelationshipMapState.map
  }

  var workspaceRelationshipMapErrorMessage: String? {
    workspaceRelationshipMapState.errorMessage
  }

  var isLoadingWorkspaceRelationshipMap: Bool {
    workspaceRelationshipMapState.isLoading
  }
}
