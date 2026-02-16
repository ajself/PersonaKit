import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned library editor and copy-flow model used by `WorkspaceStore`.
@MainActor
final class WorkspaceLibraryFeatureModel {
  let operationRunner: WorkspaceOperationRunner
  var state = WorkspaceLibraryActionState()

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

  func resetState() {
    state.reset()
  }
}
