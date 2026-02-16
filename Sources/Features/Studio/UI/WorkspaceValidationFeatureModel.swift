import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned validation model used by `WorkspaceStore`.
@MainActor
final class WorkspaceValidationFeatureModel {
  private let operationRunner: WorkspaceOperationRunner

  private var validationTask: Task<Void, Never>?
  private var state = WorkspaceValidationState()
  private var activeWorkspaceURL: URL?

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
  }

  var validation: WorkspaceValidationSnapshot {
    get {
      state.snapshot
    }

    set {
      state.setSnapshot(newValue)
    }
  }

  var validationErrorMessage: String? {
    get {
      state.errorMessage
    }

    set {
      state.setErrorMessage(newValue)
    }
  }

  func cancelValidationTask() {
    validationTask?.cancel()
    validationTask = nil
  }

  func reset() {
    state.setSnapshot(.empty)
    state.setErrorMessage(nil)
  }

  func runValidation(
    workspaceURL: URL,
    snapshotAtValidationStart: WorkspaceSnapshot
  ) {
    cancelValidationTask()
    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    activeWorkspaceURL = requestedWorkspaceURL
    state.setSnapshot(
      WorkspaceValidationSnapshot(
        summary: "Validating workspace...",
        issues: []
      )
    )
    state.setErrorMessage(nil)

    validationTask = Task { [requestedWorkspaceURL, snapshotAtValidationStart] in
      do {
        let validation = try await operationRunner.validate(
          workspaceURL: requestedWorkspaceURL,
          snapshot: snapshotAtValidationStart
        )

        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL
        else {
          return
        }

        state.setSnapshot(validation)
        state.setErrorMessage(nil)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL
        else {
          return
        }

        state.setSnapshot(.empty)
        state.setErrorMessage(error.message)
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL
        else {
          return
        }

        state.setSnapshot(.empty)
        state.setErrorMessage(error.localizedDescription)
      }
    }
  }
}
