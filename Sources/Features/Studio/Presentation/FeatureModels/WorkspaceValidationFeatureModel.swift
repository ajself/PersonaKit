import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned validation model used by `WorkspaceStore`.
@Observable
@MainActor
final class WorkspaceValidationFeatureModel {
  @ObservationIgnored private let operationRunner: WorkspaceOperationRunner

  @ObservationIgnored private var validationTask: Task<Void, Never>?
  private var state = WorkspaceValidationState()
  @ObservationIgnored private var activeWorkspaceURL: URL?

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
    activeWorkspaceURL = nil
  }

  func reset() {
    activeWorkspaceURL = nil
    state.setSnapshot(.empty)
    state.setErrorMessage(nil)
  }

  /// Validates the workspace. `showsProgress: false` keeps the current results on screen
  /// until the new ones arrive, so background revalidation after a file change doesn't flash.
  func runValidation(
    workspaceURL: URL,
    snapshotAtValidationStart: WorkspaceSnapshot,
    showsProgress: Bool = true
  ) {
    cancelValidationTask()
    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    activeWorkspaceURL = requestedWorkspaceURL

    if showsProgress {
      state.setSnapshot(
        WorkspaceValidationSnapshot(
          summary: "Validating workspace...",
          issues: []
        )
      )
      state.setErrorMessage(nil)
    }

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
