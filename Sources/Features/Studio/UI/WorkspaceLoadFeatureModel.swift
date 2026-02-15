import ContextCore
import Foundation
import StudioFoundation

/// Feature-owned workspace loading model used by `WorkspaceStore`.
@MainActor
final class WorkspaceLoadFeatureModel {
  private let operationRunner: WorkspaceOperationRunner
  private var loadTask: Task<Void, Never>?

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
  }

  func cancelLoadTask() {
    loadTask?.cancel()
    loadTask = nil
  }

  /// Loads the workspace snapshot and emits callbacks only for the active workspace selection.
  func loadWorkspace(
    workspaceURL: URL,
    currentWorkspaceURL: @MainActor @escaping () -> URL?,
    onLoaded: @MainActor @escaping (WorkspaceSnapshot) -> Void,
    onMissingPersonaKitDirectory: @MainActor @escaping (MissingPersonaKitDirectoryError) -> Void,
    onLoadFailure: @MainActor @escaping (String) -> Void
  ) {
    cancelLoadTask()

    loadTask = Task { [workspaceURL] in
      do {
        let snapshot = try await operationRunner.loadSnapshot(workspaceURL: workspaceURL)

        guard !Task.isCancelled,
          currentWorkspaceURL() == workspaceURL
        else {
          return
        }

        onLoaded(snapshot)
      } catch let error as MissingPersonaKitDirectoryError {
        guard !Task.isCancelled,
          currentWorkspaceURL() == workspaceURL
        else {
          return
        }

        onMissingPersonaKitDirectory(error)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          currentWorkspaceURL() == workspaceURL
        else {
          return
        }

        onLoadFailure(error.message)
      } catch {
        guard !Task.isCancelled,
          currentWorkspaceURL() == workspaceURL
        else {
          return
        }

        onLoadFailure(error.localizedDescription)
      }
    }
  }
}
