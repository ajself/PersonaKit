import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceSessionFeatureModel {
  func refreshMap(
    for session: WorkspaceSessionListItem?,
    workspaceURL: URL?
  ) {
    cancelMapTask()

    guard let session else {
      clearMap()
      return
    }

    guard let workspaceURL else {
      clearMap()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL
    let requestKey = "session:\(session.id)"

    activeMapWorkspaceURL = requestedWorkspaceURL
    mapState.beginLoading(requestKey: requestKey)

    mapTask = Task { [requestedWorkspaceURL, requestKey, session] in
      do {
        let draft = try await operationRunner.loadSessionDraft(fileURL: session.fileURL)
        let map = try await operationRunner.loadSessionMap(
          workspaceURL: requestedWorkspaceURL,
          personaId: draft.personaId,
          directiveId: draft.directiveId,
          kitOverrides: draft.kitOverrides
        )

        guard !Task.isCancelled,
          activeMapWorkspaceURL == requestedWorkspaceURL,
          mapState.requestKey == requestKey
        else {
          return
        }

        mapState.setLoadedMap(map)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeMapWorkspaceURL == requestedWorkspaceURL,
          mapState.requestKey == requestKey
        else {
          return
        }

        mapState.setFailedMap(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeMapWorkspaceURL == requestedWorkspaceURL,
          mapState.requestKey == requestKey
        else {
          return
        }

        mapState.setFailedMap(message: error.localizedDescription)
      }
    }
  }

  func refreshMap(
    for draft: WorkspaceSessionDraft,
    workspaceURL: URL?
  ) {
    cancelDraftMapTask()

    guard let workspaceURL else {
      clearDraftMap()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL
    let requestKey = makeDraftMapRequestKey(draft)

    activeDraftMapWorkspaceURL = requestedWorkspaceURL
    draftMapState.beginLoading(requestKey: requestKey)

    draftMapTask = Task { [requestedWorkspaceURL, requestKey, draft] in
      do {
        let map = try await operationRunner.loadSessionMap(
          workspaceURL: requestedWorkspaceURL,
          personaId: draft.personaId,
          directiveId: draft.directiveId,
          kitOverrides: draft.kitOverrides
        )

        guard !Task.isCancelled,
          activeDraftMapWorkspaceURL == requestedWorkspaceURL,
          draftMapState.requestKey == requestKey
        else {
          return
        }

        draftMapState.setLoadedMap(map)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeDraftMapWorkspaceURL == requestedWorkspaceURL,
          draftMapState.requestKey == requestKey
        else {
          return
        }

        draftMapState.setFailedMap(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeDraftMapWorkspaceURL == requestedWorkspaceURL,
          draftMapState.requestKey == requestKey
        else {
          return
        }

        draftMapState.setFailedMap(message: error.localizedDescription)
      }
    }
  }

  func restoreMapIfPossible(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?
  ) {
    guard let requestKey = mapState.requestKey else {
      clearMap()
      return
    }

    guard requestKey.hasPrefix("session:") else {
      clearMap()
      return
    }

    let sessionID = String(requestKey.dropFirst("session:".count))

    guard let session = snapshot.sessions.first(where: { $0.id == sessionID }) else {
      clearMap()
      return
    }

    refreshMap(
      for: session,
      workspaceURL: workspaceURL
    )
  }

  func cancelMapTask() {
    mapTask?.cancel()
    mapTask = nil
    activeMapWorkspaceURL = nil
  }

  func cancelDraftMapTask() {
    draftMapTask?.cancel()
    draftMapTask = nil
    activeDraftMapWorkspaceURL = nil
  }

  func clearMap() {
    cancelMapTask()
    mapState.clear()
  }

  func clearDraftMap() {
    cancelDraftMapTask()
    draftMapState.clear()
  }

  func refreshWorkspaceRelationshipMap(workspaceURL: URL?) {
    cancelWorkspaceRelationshipMapTask()

    guard let workspaceURL else {
      clearWorkspaceRelationshipMap()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL
    let requestKey = "workspace:\(requestedWorkspaceURL.path())"

    activeWorkspaceRelationshipMapURL = requestedWorkspaceURL
    workspaceRelationshipMapState.beginLoading(requestKey: requestKey)

    workspaceRelationshipMapTask = Task { [requestKey, requestedWorkspaceURL] in
      do {
        let map = try await operationRunner.loadWorkspaceRelationshipMap(
          workspaceURL: requestedWorkspaceURL
        )

        guard !Task.isCancelled,
          activeWorkspaceRelationshipMapURL == requestedWorkspaceURL,
          workspaceRelationshipMapState.requestKey == requestKey
        else {
          return
        }

        workspaceRelationshipMapState.setLoadedMap(map)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceRelationshipMapURL == requestedWorkspaceURL,
          workspaceRelationshipMapState.requestKey == requestKey
        else {
          return
        }

        workspaceRelationshipMapState.setFailedMap(message: error.message)
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceRelationshipMapURL == requestedWorkspaceURL,
          workspaceRelationshipMapState.requestKey == requestKey
        else {
          return
        }

        workspaceRelationshipMapState.setFailedMap(message: error.localizedDescription)
      }
    }
  }

  func cancelWorkspaceRelationshipMapTask() {
    workspaceRelationshipMapTask?.cancel()
    workspaceRelationshipMapTask = nil
    activeWorkspaceRelationshipMapURL = nil
  }

  func clearWorkspaceRelationshipMap() {
    cancelWorkspaceRelationshipMapTask()
    workspaceRelationshipMapState.clear()
  }

  private func makeDraftMapRequestKey(_ draft: WorkspaceSessionDraft) -> String {
    let sortedKitOverrides = draft.kitOverrides.sorted()

    return "draft:\(draft.personaId)::\(draft.directiveId)::\(sortedKitOverrides.joined(separator: ","))"
  }
}
