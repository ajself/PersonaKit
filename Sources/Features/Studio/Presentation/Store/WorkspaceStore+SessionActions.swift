import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
  /// Saves a session draft to project scope and refreshes workspace data.
  func saveSession(
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    expectedWorkspaceURL: URL? = nil,
    expectedOriginalSessionFileURL: URL? = nil
  ) async throws -> String {
    try await sessionEditorFeatureModel.saveSession(
      draft: draft,
      originalSessionID: originalSessionID,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      expectedWorkspaceURL: expectedWorkspaceURL,
      expectedOriginalSessionFileURL: expectedOriginalSessionFileURL,
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Loads markdown preview text for the selected session.
  func refreshSessionPreview(
    for session: WorkspaceSessionListItem?,
    forceReload: Bool = false
  ) {
    sessionFeatureModel.refreshPreview(
      for: session,
      workspaceURL: workspaceURL,
      forceReload: forceReload
    )
  }

  /// Loads a dependency map for the selected session.
  func refreshSessionMap(
    for session: WorkspaceSessionListItem?,
    forceReload: Bool = false
  ) {
    sessionFeatureModel.refreshMap(
      for: session,
      workspaceURL: workspaceURL,
      forceReload: forceReload
    )
  }

  /// Cancels any in-flight session preview refresh task.
  func cancelSessionPreviewRefresh() {
    sessionFeatureModel.cancelPreviewTask()
  }

  /// Drops the session map so a hidden map neither rebuilds on reload nor reports stale health.
  func clearSessionMap() {
    sessionFeatureModel.clearMap()
  }

  /// Loads a dependency map for an in-flight session draft.
  func refreshDraftSessionMap(
    for draft: WorkspaceSessionDraft
  ) {
    sessionFeatureModel.refreshMap(
      for: draft,
      workspaceURL: workspaceURL
    )
  }

  /// Clears in-flight draft map state when the session editor is dismissed.
  func clearDraftSessionMap() {
    sessionFeatureModel.clearDraftMap()
  }

  func presentNewSessionEditor() {
    sessionEditorFeatureModel.presentNewSessionEditor(
      snapshot: snapshot,
      workspaceURL: workspaceURL
    )
  }

  /// Loads `session` and opens it for editing (or copying, for a global session).
  func presentSessionEditor(for session: WorkspaceSessionListItem) {
    sessionEditorFeatureModel.presentEditor(
      for: session,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL }
    )
  }

  func dismissSessionEditor() {
    sessionEditorFeatureModel.dismissEditor()
    sessionFeatureModel.clearDraftMap()
  }

  func requestSessionDeletion(_ session: WorkspaceSessionListItem) {
    sessionEditorFeatureModel.requestDeletion(
      of: session,
      workspaceURL: workspaceURL
    )
  }

  func cancelSessionDeletion() {
    sessionEditorFeatureModel.cancelDeletion()
  }

  func confirmSessionDeletion(
    _ presentation: SessionDeletionPresentation,
    onDeleted: @MainActor @escaping (String) -> Void
  ) {
    sessionEditorFeatureModel.confirmDeletion(
      presentation,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      onWorkspaceMutation: { self.loadWorkspace() },
      onDeleted: onDeleted
    )
  }

  /// Drops work tied to the previous selection: a pending editor load and the last
  /// Copy/Export message.
  func sessionSelectionDidChange() {
    sessionEditorFeatureModel.cancelPendingEditorLoad()
    sessionFeatureModel.clearPreviewActionMessage()
  }

  func clearSessionPreviewActionMessage() {
    sessionFeatureModel.clearPreviewActionMessage()
  }

  func copySessionPreviewReportingResult() {
    sessionFeatureModel.copyPreviewReportingResult()
  }

  func exportSessionPreviewReportingResult() {
    sessionFeatureModel.exportPreviewReportingResult()
  }
}
