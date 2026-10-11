import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceSessionFeatureModel {
  func refreshMap(
    for session: WorkspaceSessionListItem?,
    workspaceURL: URL?,
    forceReload: Bool = false
  ) {
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
    let isSameMapRequest = mapState.requestKey == requestKey

    if !forceReload, isSameMapRequest {
      if mapState.isLoading, mapTask != nil {
        return
      }

      if !mapState.isLoading,
        mapState.errorMessage == nil,
        mapState.map != nil
      {
        return
      }
    }

    cancelMapTask()

    activeMapWorkspaceURL = requestedWorkspaceURL
    mapWorkspaceURL = requestedWorkspaceURL
    mapState.beginLoading(requestKey: requestKey)

    mapTask = Task { [requestedWorkspaceURL, requestKey, session] in
      let outcome = await loadMapOutcome(workspaceURL: requestedWorkspaceURL, session: session)

      guard isCurrentMapRequest(workspaceURL: requestedWorkspaceURL, requestKey: requestKey) else {
        return
      }

      switch outcome {
      case .loaded(let map):
        mapState.setLoadedMap(map)
      case .failed(let message):
        mapState.setFailedMap(message: message)
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

  /// Brings the session map up to date after a workspace reload, mirroring
  /// ``revalidatePreviewAfterReload(snapshot:workspaceURL:changedFileURLs:)``: the current map
  /// stays on screen and is replaced only when the rebuilt one differs.
  func revalidateMapAfterReload(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    changedFileURLs: Set<URL>?
  ) {
    guard let requestKey = mapState.requestKey,
      requestKey.hasPrefix("session:"),
      let session = snapshot.sessions.first(where: {
        $0.id == String(requestKey.dropFirst("session:".count))
      }),
      let workspaceURL
    else {
      clearMap()
      return
    }

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    guard !mapState.isLoading, mapWorkspaceURL == requestedWorkspaceURL else {
      refreshMap(for: session, workspaceURL: workspaceURL, forceReload: true)
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

    cancelMapTask()
    activeMapWorkspaceURL = requestedWorkspaceURL

    mapTask = Task { [requestedWorkspaceURL, requestKey, session] in
      let outcome = await loadMapOutcome(workspaceURL: requestedWorkspaceURL, session: session)

      guard isCurrentMapRequest(workspaceURL: requestedWorkspaceURL, requestKey: requestKey) else {
        return
      }

      switch outcome {
      case .loaded(let map):
        guard map != mapState.map || mapState.errorMessage != nil else {
          return
        }

        mapState.setLoadedMap(map)
      case .failed(let message):
        guard message != mapState.errorMessage || mapState.map != nil else {
          return
        }

        mapState.setFailedMap(message: message)
      }
    }
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
    mapWorkspaceURL = nil
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

  private func isCurrentMapRequest(
    workspaceURL: URL,
    requestKey: String
  ) -> Bool {
    !Task.isCancelled
      && activeMapWorkspaceURL == workspaceURL
      && mapState.requestKey == requestKey
  }

  private func loadMapOutcome(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) async -> WorkspaceLoadOutcome<WorkspaceSessionMap> {
    do {
      let draft = try await operationRunner.loadSessionDraft(fileURL: session.fileURL)

      return .loaded(
        try await operationRunner.loadSessionMap(
          workspaceURL: workspaceURL,
          personaId: draft.personaId,
          directiveId: draft.directiveId,
          kitOverrides: draft.kitOverrides
        )
      )
    } catch let error as WorkspaceSnapshotBuildError {
      return .failed(error.message)
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  private func makeDraftMapRequestKey(_ draft: WorkspaceSessionDraft) -> String {
    let sortedKitOverrides = draft.kitOverrides.sorted()

    return "draft:\(draft.personaId)::\(draft.directiveId)::\(sortedKitOverrides.joined(separator: ","))"
  }
}
