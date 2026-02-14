import AppKit
import Foundation
import Observation
import PersonaKitCore

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
final class WorkspaceStore {
  var workspaceURL: URL?
  var snapshot: WorkspaceSnapshot = .empty
  var loadErrorMessage: String?
  var validation: WorkspaceValidationSnapshot = .empty
  var validationErrorMessage: String?

  private let operationRunner: WorkspaceOperationRunner
  private var loadTask: Task<Void, Never>?
  private var validationTask: Task<Void, Never>?

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator()
  ) {
    self.operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator
    )
  }

  /// Presents the folder picker and loads the selected workspace snapshot.
  func openWorkspacePicker() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    panel.message = "Choose a folder to use as the PersonaKit workspace."
    panel.prompt = "Open Workspace"

    guard panel.runModal() == .OK,
      let selectedURL = panel.url
    else {
      return
    }

    workspaceURL = selectedURL.standardizedFileURL
    loadWorkspace()
  }

  /// Reloads workspace data into the current snapshot and error state.
  func loadWorkspace() {
    guard let workspaceURL else {
      loadTask?.cancel()
      validationTask?.cancel()
      snapshot = .empty
      loadErrorMessage = nil
      validation = .empty
      validationErrorMessage = nil
      return
    }

    loadTask?.cancel()
    validationTask?.cancel()

    loadTask = Task { [workspaceURL] in
      do {
        let snapshot = try await operationRunner.loadSnapshot(workspaceURL: workspaceURL)

        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        self.snapshot = snapshot
        loadErrorMessage = nil
        validation = .empty
        validationErrorMessage = nil
        runValidationTask(for: workspaceURL)
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        snapshot = .empty
        loadErrorMessage = error.message
        validation = .empty
        validationErrorMessage = nil
      } catch {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        snapshot = .empty
        loadErrorMessage = error.localizedDescription
        validation = .empty
        validationErrorMessage = nil
      }
    }
  }

  /// Runs validator checks and refreshes diagnostics state.
  func validateWorkspace() {
    guard let workspaceURL else {
      validationTask?.cancel()
      validation = .empty
      validationErrorMessage = nil
      return
    }

    runValidationTask(for: workspaceURL)
  }

  private func runValidationTask(for workspaceURL: URL) {
    validationTask?.cancel()
    validation = WorkspaceValidationSnapshot(
      summary: "Validating workspace...",
      issues: []
    )
    validationErrorMessage = nil

    validationTask = Task { [workspaceURL] in
      do {
        let validation = try await operationRunner.validate(workspaceURL: workspaceURL)

        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        self.validation = validation
        validationErrorMessage = nil
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        validation = .empty
        validationErrorMessage = error.message
      } catch {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        validation = .empty
        validationErrorMessage = error.localizedDescription
      }
    }
  }
}

private actor WorkspaceOperationRunner {
  private let snapshotBuilder: any WorkspaceSnapshotBuilding
  private let workspaceValidator: any WorkspaceValidating

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding,
    workspaceValidator: any WorkspaceValidating
  ) {
    self.snapshotBuilder = snapshotBuilder
    self.workspaceValidator = workspaceValidator
  }

  func loadSnapshot(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try snapshotBuilder.build(workspaceURL: workspaceURL)
  }

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try workspaceValidator.validate(workspaceURL: workspaceURL)
  }
}
