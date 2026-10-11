import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned session preview model used by `WorkspaceStore`.
@Observable
@MainActor
final class WorkspaceSessionFeatureModel {
  @ObservationIgnored let operationRunner: WorkspaceOperationRunner
  @ObservationIgnored let previewExportDestinationPicker: any PreviewExportDestinationPicking
  @ObservationIgnored let pasteboardWriter: any PasteboardWriting

  @ObservationIgnored var previewTask: Task<Void, Never>?
  @ObservationIgnored var previewExportTask: Task<Void, Never>?
  @ObservationIgnored var mapTask: Task<Void, Never>?
  @ObservationIgnored var draftMapTask: Task<Void, Never>?
  @ObservationIgnored var workspaceRelationshipMapTask: Task<Void, Never>?
  var state = WorkspaceSessionPreviewState()
  // Result of the last Copy or Export action, shown under the preview header.
  var previewActionMessage: String?
  var mapState = WorkspaceSessionMapState()
  var draftMapState = WorkspaceSessionMapState()
  var workspaceRelationshipMapState = WorkspaceSessionMapState()
  @ObservationIgnored var activeWorkspaceURL: URL?
  @ObservationIgnored var activeMapWorkspaceURL: URL?
  @ObservationIgnored var activeDraftMapWorkspaceURL: URL?
  @ObservationIgnored var activeWorkspaceRelationshipMapURL: URL?
  // Workspace the shown preview and map were loaded for, so a reload after switching
  // workspaces shows a visible load instead of the previous workspace's contract.
  @ObservationIgnored var previewWorkspaceURL: URL?
  @ObservationIgnored var mapWorkspaceURL: URL?

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

  var mapRequestKey: String? {
    mapState.requestKey
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
