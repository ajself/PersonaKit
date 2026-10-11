import ContextCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned library editor and copy-flow model used by `WorkspaceStore`.
///
/// Owns the library panel's editor sheets, the selected item's source and inline draft,
/// and the tasks that load, validate, save, and copy on their behalf.
@Observable
@MainActor
final class WorkspaceLibraryFeatureModel {
  @ObservationIgnored let operationRunner: WorkspaceOperationRunner
  var state = WorkspaceLibraryActionState()
  var rawJSONEditorPresentation: WorkspaceLibraryEditorPresentation?
  var personaEditorPresentation: PersonaEditorPresentation?
  var detail = StudioLibraryDetailState()
  @ObservationIgnored var editorOpenTask: Task<Void, Never>?
  @ObservationIgnored var copyTask: Task<Void, Never>?
  @ObservationIgnored var detailSourceTask: Task<Void, Never>?
  @ObservationIgnored var detailActionTask: Task<Void, Never>?

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
  }
}
