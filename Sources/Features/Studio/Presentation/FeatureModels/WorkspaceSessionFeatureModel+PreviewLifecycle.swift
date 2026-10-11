import ContextCore
import ContextWorkspaceCore
import Foundation

extension WorkspaceSessionFeatureModel {
  func refreshPreview(
    for session: WorkspaceSessionListItem?,
    workspaceURL: URL?,
    forceReload: Bool = false
  ) {
    guard let session else {
      clearPreview()
      return
    }

    guard let workspaceURL else {
      clearPreview()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL
    let isSamePreviewRequest = state.previewSessionID == session.id

    if !forceReload, isSamePreviewRequest {
      if state.isLoading, previewTask != nil {
        return
      }

      if !state.isLoading, state.errorMessage == nil {
        return
      }
    }

    cancelPreviewTask()

    activeWorkspaceURL = requestedWorkspaceURL
    previewWorkspaceURL = requestedWorkspaceURL
    state.beginLoading(sessionID: session.id)

    previewTask = Task { [requestedWorkspaceURL, session] in
      let outcome = await loadPreviewOutcome(
        workspaceURL: requestedWorkspaceURL,
        session: session
      )

      guard isCurrentPreviewRequest(workspaceURL: requestedWorkspaceURL, sessionID: session.id) else {
        return
      }

      switch outcome {
      case .loaded(let preview):
        state.setLoadedPreview(preview)
      case .failed(let message):
        state.setFailedPreview(message: message)
      }
    }
  }

  /// Brings the preview up to date after a workspace reload. Edits to other sessions' files
  /// are skipped outright; otherwise the preview re-resolves in the background with the
  /// current text left on screen, and is replaced only when the result differs.
  func revalidatePreviewAfterReload(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    changedFileURLs: Set<URL>?
  ) {
    guard let previewSessionID = state.previewSessionID,
      let session = snapshot.sessions.first(where: { $0.id == previewSessionID }),
      let workspaceURL
    else {
      clearPreview()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    // Restart outright, with a visible load, when a load was in flight (it may predate the
    // change, or an explicit reload cancelled it) or the preview belongs to another workspace.
    guard !state.isLoading, previewWorkspaceURL == requestedWorkspaceURL else {
      refreshPreview(for: session, workspaceURL: workspaceURL, forceReload: true)
      return
    }

    guard
      WorkspaceFileChangeRelevance.affectsSession(
        fileURL: session.fileURL,
        changedFileURLs: changedFileURLs
      )
    else {
      return
    }

    cancelPreviewTask()
    activeWorkspaceURL = requestedWorkspaceURL

    previewTask = Task { [requestedWorkspaceURL, session] in
      let outcome = await loadPreviewOutcome(
        workspaceURL: requestedWorkspaceURL,
        session: session
      )

      guard isCurrentPreviewRequest(workspaceURL: requestedWorkspaceURL, sessionID: session.id) else {
        return
      }

      switch outcome {
      case .loaded(let preview):
        guard preview != state.preview || state.errorMessage != nil else {
          return
        }

        state.setLoadedPreview(preview)
      case .failed(let message):
        guard message != state.errorMessage || !state.preview.isEmpty else {
          return
        }

        state.setFailedPreview(message: message)
      }
    }
  }

  func cancelPreviewTask() {
    previewTask?.cancel()
    previewTask = nil
    activeWorkspaceURL = nil
  }

  func clearPreview() {
    cancelPreviewTask()
    previewWorkspaceURL = nil
    state.clear()
  }

  private func isCurrentPreviewRequest(
    workspaceURL: URL,
    sessionID: String
  ) -> Bool {
    !Task.isCancelled
      && activeWorkspaceURL == workspaceURL
      && state.previewSessionID == sessionID
  }

  private func loadPreviewOutcome(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) async -> WorkspaceLoadOutcome<String> {
    do {
      return .loaded(
        try await operationRunner.loadSessionPreview(
          workspaceURL: workspaceURL,
          session: session
        )
      )
    } catch let error as WorkspaceSnapshotBuildError {
      return .failed(error.message)
    } catch {
      return .failed(error.localizedDescription)
    }
  }
}
