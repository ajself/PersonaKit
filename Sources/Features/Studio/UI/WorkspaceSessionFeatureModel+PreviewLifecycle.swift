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

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    activeWorkspaceURL = requestedWorkspaceURL
    state.beginLoading(sessionID: session.id)

    previewTask = Task { [requestedWorkspaceURL, session] in
      do {
        let preview = try await operationRunner.loadSessionPreview(
          workspaceURL: requestedWorkspaceURL,
          session: session
        )

        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setLoadedPreview(preview)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL,
          state.previewSessionID == session.id
        else {
          return
        }

        state.setFailedPreview(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL,
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
