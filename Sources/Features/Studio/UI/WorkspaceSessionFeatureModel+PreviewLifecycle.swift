import ContextCore
import Foundation

extension WorkspaceSessionFeatureModel {
  func refreshPreview(
    for session: WorkspaceSessionListItem?,
    workspaceURL: URL?
  ) {
    cancelPreviewTask()

    guard let session else {
      clearPreview()
      return
    }

    guard let workspaceURL else {
      clearPreview()
      return
    }

    activeWorkspaceURL = workspaceURL
    state.beginLoading(sessionID: session.id)

    previewTask = Task { [workspaceURL, session] in
      do {
        let preview = try await operationRunner.loadSessionPreview(
          workspaceURL: workspaceURL,
          session: session
        )

        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setLoadedPreview(preview)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setFailedPreview(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceURL == workspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setFailedPreview(message: error.localizedDescription)
      }
    }
  }

  func restorePreviewIfPossible(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?
  ) {
    guard let previewSessionID = state.previewSessionID,
      let session = snapshot.sessions.first(where: { $0.id == previewSessionID })
    else {
      clearPreview()
      return
    }

    refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )
  }

  func cancelPreviewTask() {
    previewTask?.cancel()
    previewTask = nil
  }

  func clearPreview() {
    cancelPreviewTask()
    activeWorkspaceURL = nil
    state.clear()
  }
}
