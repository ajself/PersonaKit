import ContextCore
import ContextWorkspaceCore
import StudioFoundation

extension WorkspaceStore {
  /// Creates a prefilled draft for new-session creation.
  func defaultSessionDraft() -> WorkspaceSessionDraft {
    sessionEditorFeatureModel.defaultSessionDraft(
      snapshot: snapshot
    )
  }

  /// Loads an editable session draft from an existing on-disk session file.
  func loadSessionDraft(
    for session: WorkspaceSessionListItem
  ) async throws -> WorkspaceSessionDraft {
    try await sessionEditorFeatureModel.loadSessionDraft(
      for: session
    )
  }

  /// Saves a session draft to project scope and refreshes workspace data.
  func saveSession(
    draft: WorkspaceSessionDraft,
    originalSessionID: String?
  ) async throws -> String {
    try await sessionEditorFeatureModel.saveSession(
      draft: draft,
      originalSessionID: originalSessionID,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Deletes a project-scoped session file and refreshes workspace data.
  func deleteSession(sessionID: String) async throws {
    try await sessionEditorFeatureModel.deleteSession(
      sessionID: sessionID,
      workspaceURL: workspaceURL,
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

  /// Cancels any in-flight session map refresh task.
  func cancelSessionMapRefresh() {
    sessionFeatureModel.cancelMapTask()
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

  /// Loads or reloads the workspace-wide relationship map.
  func refreshWorkspaceRelationshipMap() {
    sessionFeatureModel.refreshWorkspaceRelationshipMap(workspaceURL: workspaceURL)
  }

  /// Clears workspace-wide relationship map state.
  func clearWorkspaceRelationshipMap() {
    sessionFeatureModel.clearWorkspaceRelationshipMap()
  }

  /// Copies the current preview text into the system pasteboard.
  func copySessionPreviewToPasteboard() throws {
    try sessionFeatureModel.copyPreviewToPasteboard()
  }

  /// Presents a save panel and exports preview markdown to the selected path.
  func exportSessionPreviewWithSavePanel() async throws -> Bool {
    try await sessionFeatureModel.exportPreviewWithSavePanel()
  }
}
