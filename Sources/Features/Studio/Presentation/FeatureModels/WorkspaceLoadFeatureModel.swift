import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned workspace loading model used by `WorkspaceStore`.
///
/// Also owns live reload: it watches the workspace's PersonaKit directories and reports
/// debounced batches of changed files so the store can reload.
@Observable
@MainActor
final class WorkspaceLoadFeatureModel {
  static let defaultFileChangeDebounceInterval = Duration.milliseconds(300)

  @ObservationIgnored private let operationRunner: WorkspaceOperationRunner
  @ObservationIgnored private let fileEventSource: (any WorkspaceFileEventStreaming)?
  @ObservationIgnored private let clock: any Clock<Duration>
  @ObservationIgnored private let fileChangeDebounceInterval: Duration
  @ObservationIgnored private var loadTask: Task<Void, Never>?
  @ObservationIgnored private var watchTask: Task<Void, Never>?
  @ObservationIgnored private var debounceTask: Task<Void, Never>?
  @ObservationIgnored private var pendingChangedFileURLs: Set<URL> = []
  private(set) var watchedDirectories: [URL] = []

  /// `fileEventSource == nil` disables live reload (the default outside the launched app).
  init(
    operationRunner: WorkspaceOperationRunner,
    fileEventSource: (any WorkspaceFileEventStreaming)? = nil,
    clock: any Clock<Duration> = ContinuousClock(),
    fileChangeDebounceInterval: Duration = WorkspaceLoadFeatureModel.defaultFileChangeDebounceInterval
  ) {
    self.operationRunner = operationRunner
    self.fileEventSource = fileEventSource
    self.clock = clock
    self.fileChangeDebounceInterval = fileChangeDebounceInterval
  }

  /// Watches `directories` and calls `onChange` once per quiet period with every file that
  /// changed during it. Re-watching the same directories keeps the running watch.
  func startWatching(
    directories: [URL],
    onChange: @MainActor @escaping (Set<URL>) -> Void
  ) {
    let directories = directories.map(\.standardizedFileURL).sorted { $0.path < $1.path }

    guard directories != watchedDirectories || watchTask == nil else {
      return
    }

    stopWatching()

    guard let fileEventSource, !directories.isEmpty else {
      return
    }

    watchedDirectories = directories
    let changes = fileEventSource.changes(in: directories)

    watchTask = Task { [weak self] in
      for await changedFileURLs in changes {
        guard let self, !Task.isCancelled else {
          return
        }

        self.recordFileChanges(changedFileURLs, onChange: onChange)
      }
    }
  }

  func stopWatching() {
    watchTask?.cancel()
    watchTask = nil
    debounceTask?.cancel()
    debounceTask = nil
    pendingChangedFileURLs = []
    watchedDirectories = []
  }

  private func recordFileChanges(
    _ changedFileURLs: [URL],
    onChange: @MainActor @escaping (Set<URL>) -> Void
  ) {
    let meaningfulChanges = WorkspaceFileChangeRelevance.meaningfulChanges(changedFileURLs)

    guard !meaningfulChanges.isEmpty else {
      return
    }

    pendingChangedFileURLs.formUnion(meaningfulChanges)
    debounceTask?.cancel()
    debounceTask = Task { [weak self, clock, fileChangeDebounceInterval] in
      do {
        try await clock.sleep(for: fileChangeDebounceInterval)
      } catch {
        return
      }

      guard let self, !Task.isCancelled else {
        return
      }

      let changes = self.pendingChangedFileURLs
      self.pendingChangedFileURLs = []
      self.debounceTask = nil
      onChange(changes)
    }
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

    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    loadTask = Task { [requestedWorkspaceURL] in
      do {
        let snapshot = try await operationRunner.loadSnapshot(workspaceURL: requestedWorkspaceURL)
        let currentWorkspace = currentWorkspaceURL()?.standardizedFileURL

        guard !Task.isCancelled,
          currentWorkspace == requestedWorkspaceURL
        else {
          return
        }

        onLoaded(snapshot)
      } catch let error as MissingPersonaKitDirectoryError {
        let currentWorkspace = currentWorkspaceURL()?.standardizedFileURL

        guard !Task.isCancelled,
          currentWorkspace == requestedWorkspaceURL
        else {
          return
        }

        onMissingPersonaKitDirectory(error)
      } catch let error as WorkspaceSnapshotBuildError {
        let currentWorkspace = currentWorkspaceURL()?.standardizedFileURL

        guard !Task.isCancelled,
          currentWorkspace == requestedWorkspaceURL
        else {
          return
        }

        onLoadFailure(error.message)
      } catch {
        let currentWorkspace = currentWorkspaceURL()?.standardizedFileURL

        guard !Task.isCancelled,
          currentWorkspace == requestedWorkspaceURL
        else {
          return
        }

        onLoadFailure(error.localizedDescription)
      }
    }
  }
}

/// Result of an async load whose failure is shown to the user as a message.
enum WorkspaceLoadOutcome<Value> {
  case loaded(Value)
  case failed(String)
}
