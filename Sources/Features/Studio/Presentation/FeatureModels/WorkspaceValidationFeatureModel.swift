import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

/// Feature-owned validation model used by `WorkspaceStore`.
@MainActor
final class WorkspaceValidationFeatureModel {
  private let operationRunner: WorkspaceOperationRunner

  private var validationTask: Task<Void, Never>?
  private var state = WorkspaceValidationState()
  private var activeWorkspaceURL: URL?
  var onChange: (() -> Void)?

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
  }

  var validation: WorkspaceValidationSnapshot {
    get {
      state.snapshot
    }

    set {
      state.setSnapshot(newValue)
      onChange?()
    }
  }

  var validationErrorMessage: String? {
    get {
      state.errorMessage
    }

    set {
      state.setErrorMessage(newValue)
      onChange?()
    }
  }

  func cancelValidationTask() {
    validationTask?.cancel()
    validationTask = nil
    activeWorkspaceURL = nil
  }

  func reset() {
    activeWorkspaceURL = nil
    state.setSnapshot(.empty)
    state.setErrorMessage(nil)
    onChange?()
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
    onChange?()

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
        onChange?()
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL
        else {
          return
        }

        state.setSnapshot(.empty)
        state.setErrorMessage(error.message)
        onChange?()
      } catch {
        guard !Task.isCancelled,
          activeWorkspaceURL == requestedWorkspaceURL
        else {
          return
        }

        state.setSnapshot(.empty)
        state.setErrorMessage(error.localizedDescription)
        onChange?()
      }
    }
  }
}
