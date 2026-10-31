import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned library editor and copy-flow model used by `WorkspaceStore`.
///
/// Owns the library panel's editor sheets, the selected item's source and inline draft,
/// the workspace graph behind "Used by", and the tasks that load, validate, save, and copy
/// on their behalf.
@Observable
@MainActor
final class WorkspaceLibraryFeatureModel {
  @ObservationIgnored let operationRunner: WorkspaceOperationRunner
  var state = WorkspaceLibraryActionState()
  var rawJSONEditorPresentation: WorkspaceLibraryEditorPresentation?
  var personaEditorPresentation: PersonaEditorPresentation?
  var detail = StudioLibraryDetailState()
  // Last successfully loaded workspace graph; kept on screen when a reload's graph fails.
  var usageGraph: WorkspaceSessionMap?
  // True when the latest graph load failed with no earlier graph to fall back on.
  var usageGraphLoadFailed = false
  @ObservationIgnored var editorOpenTask: Task<Void, Never>?
  @ObservationIgnored var copyTask: Task<Void, Never>?
  @ObservationIgnored var detailSourceTask: Task<Void, Never>?
  @ObservationIgnored var detailActionTask: Task<Void, Never>?
  @ObservationIgnored var usageGraphTask: Task<Void, Never>?
  @ObservationIgnored var usageGraphWorkspaceURL: URL?

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

  // Not observable: `usageGraphTask` is ignored, so a view must not bind to this.
  var isLoadingUsageGraph: Bool {
    usageGraphTask != nil
  }

  func invalidateRequests() {
    state.invalidateRequests()
  }

  /// Clears messages, sheets, and the detail pane when the workspace changes or closes.
  func resetState() {
    state.reset()
    editorOpenTask?.cancel()
    editorOpenTask = nil
    copyTask?.cancel()
    copyTask = nil
    rawJSONEditorPresentation = nil
    personaEditorPresentation = nil
    selectDetailItem(nil)
    clearUsageGraph()
  }
}
