import ContextWorkspaceCore

/// Package-scoped list action state for Sessions CRUD controls.
struct SessionsListActionState {
  let canCreate: Bool
  let canEdit: Bool
  let canReveal: Bool
  let canDelete: Bool
  let isLoadingDraft: Bool

  init(
    selectedSession: WorkspaceSessionListItem?,
    isLoadingSessionDraft: Bool
  ) {
    let hasSelection = selectedSession != nil
    canCreate = true
    canEdit = hasSelection && !isLoadingSessionDraft
    canReveal = hasSelection
    canDelete = selectedSession?.sourceScope == .project && !isLoadingSessionDraft
    isLoadingDraft = isLoadingSessionDraft
  }
}
