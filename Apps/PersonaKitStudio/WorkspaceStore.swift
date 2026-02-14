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
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager()
  ) {
    self.operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager
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

  /// Creates a prefilled draft for new-session creation.
  func defaultSessionDraft() -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: "",
      personaId: snapshot.personas.first?.id ?? "",
      directiveId: snapshot.directives.first?.id ?? "",
      kitOverrides: []
    )
  }

  /// Loads an editable session draft from an existing on-disk session file.
  func loadSessionDraft(
    for session: WorkspaceSessionListItem
  ) async throws -> WorkspaceSessionDraft {
    try await operationRunner.loadSessionDraft(fileURL: session.fileURL)
  }

  /// Saves a session draft to project scope and refreshes workspace data.
  func saveSession(
    draft: WorkspaceSessionDraft,
    originalSessionID: String?
  ) async throws -> String {
    let workspaceURL = try requiredWorkspaceURL()

    let sessionID = try await operationRunner.saveSession(
      workspaceURL: workspaceURL,
      draft: draft,
      originalSessionID: originalSessionID,
      validPersonaIDs: Set(snapshot.personas.map(\.id)),
      validDirectiveIDs: Set(snapshot.directives.map(\.id))
    )

    loadWorkspace()
    return sessionID
  }

  /// Deletes a project-scoped session file and refreshes workspace data.
  func deleteSession(sessionID: String) async throws {
    let workspaceURL = try requiredWorkspaceURL()

    try await operationRunner.deleteSession(
      workspaceURL: workspaceURL,
      sessionID: sessionID
    )

    loadWorkspace()
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

  private func requiredWorkspaceURL() throws -> URL {
    guard let workspaceURL else {
      throw WorkspaceSnapshotBuildError(
        message: "No workspace is currently selected."
      )
    }

    return workspaceURL
  }
}

private actor WorkspaceOperationRunner {
  private let snapshotBuilder: any WorkspaceSnapshotBuilding
  private let workspaceValidator: any WorkspaceValidating
  private let sessionManager: any WorkspaceSessionManaging

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding,
    workspaceValidator: any WorkspaceValidating,
    sessionManager: any WorkspaceSessionManaging
  ) {
    self.snapshotBuilder = snapshotBuilder
    self.workspaceValidator = workspaceValidator
    self.sessionManager = sessionManager
  }

  func loadSnapshot(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try snapshotBuilder.build(workspaceURL: workspaceURL)
  }

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try workspaceValidator.validate(workspaceURL: workspaceURL)
  }

  func loadSessionDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try sessionManager.loadDraft(fileURL: fileURL)
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>
  ) throws -> String {
    try sessionManager.saveSession(
      workspaceURL: workspaceURL,
      draft: draft,
      originalSessionID: originalSessionID,
      validPersonaIDs: validPersonaIDs,
      validDirectiveIDs: validDirectiveIDs
    )
  }

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {
    try sessionManager.deleteSession(
      workspaceURL: workspaceURL,
      sessionID: sessionID
    )
  }
}
