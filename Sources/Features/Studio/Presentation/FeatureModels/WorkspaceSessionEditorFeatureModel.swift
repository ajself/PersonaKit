import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Feature-owned session editor model used by `WorkspaceStore`.
///
/// Owns the editor sheet and delete confirmation for the Sessions panel, plus the tasks that
/// load drafts and delete files on their behalf.
@Observable
@MainActor
final class WorkspaceSessionEditorFeatureModel {
  @ObservationIgnored private let operationRunner: WorkspaceOperationRunner
  @ObservationIgnored private var draftLoadTask: Task<Void, Never>?
  @ObservationIgnored private var deleteTask: Task<Void, Never>?

  private(set) var editorPresentation: SessionEditorPresentation?
  private(set) var pendingDeletion: SessionDeletionPresentation?
  private(set) var isLoadingDraft = false
  private(set) var actionErrorMessage: String?

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
  }

  func presentNewSessionEditor(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?
  ) {
    guard let workspaceURL = workspaceURL?.standardizedFileURL else {
      actionErrorMessage = "No workspace is currently selected."
      return
    }

    editorPresentation = SessionEditorPresentation(
      title: "New Session",
      originalSessionID: nil,
      originalSessionFileURL: nil,
      draft: defaultSessionDraft(snapshot: snapshot),
      workspaceURL: workspaceURL
    )
  }

  /// Loads `session` from disk and opens it for editing, or for copying when it is global.
  func presentEditor(
    for session: WorkspaceSessionListItem,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor @escaping () -> URL?
  ) {
    guard let requestWorkspaceURL = workspaceURL?.standardizedFileURL else {
      actionErrorMessage = "No workspace is currently selected."
      return
    }

    draftLoadTask?.cancel()
    isLoadingDraft = true
    actionErrorMessage = nil

    draftLoadTask = Task { [session] in
      do {
        let draft = try await loadSessionDraft(for: session)

        guard !Task.isCancelled else {
          return
        }

        isLoadingDraft = false
        draftLoadTask = nil

        guard currentWorkspaceURL()?.standardizedFileURL == requestWorkspaceURL else {
          return
        }

        let isProjectSession = session.sourceScope == .project

        editorPresentation = SessionEditorPresentation(
          title: isProjectSession ? "Edit Session" : "Copy Session to Project",
          originalSessionID: isProjectSession ? session.id : nil,
          originalSessionFileURL: isProjectSession ? session.fileURL.standardizedFileURL : nil,
          draft: draft,
          workspaceURL: requestWorkspaceURL
        )
      } catch {
        guard !Task.isCancelled else {
          return
        }

        isLoadingDraft = false
        draftLoadTask = nil
        actionErrorMessage = error.localizedDescription
      }
    }
  }

  /// Drops a pending editor load, e.g. when the selected session changes before it lands.
  func cancelPendingEditorLoad() {
    draftLoadTask?.cancel()
    draftLoadTask = nil
    isLoadingDraft = false
  }

  func dismissEditor() {
    editorPresentation = nil
  }

  func requestDeletion(
    of session: WorkspaceSessionListItem,
    workspaceURL: URL?
  ) {
    guard session.sourceScope == .project else {
      actionErrorMessage = "Global sessions are read-only. Create a project session to edit or delete."
      return
    }

    guard let workspaceURL = workspaceURL?.standardizedFileURL else {
      actionErrorMessage = "No workspace is currently selected."
      return
    }

    pendingDeletion = SessionDeletionPresentation(
      session: session,
      workspaceURL: workspaceURL
    )
    actionErrorMessage = nil
  }

  func cancelDeletion() {
    pendingDeletion = nil
  }

  /// Deletes the confirmed session; `onDeleted` runs with its id once the file is gone.
  func confirmDeletion(
    _ presentation: SessionDeletionPresentation,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    onWorkspaceMutation: @MainActor @escaping () -> Void,
    onDeleted: @MainActor @escaping (String) -> Void
  ) {
    pendingDeletion = nil
    actionErrorMessage = nil
    deleteTask?.cancel()

    deleteTask = Task { [presentation, snapshot, workspaceURL] in
      do {
        try await deleteSession(
          sessionID: presentation.session.id,
          workspaceURL: workspaceURL,
          snapshot: snapshot,
          expectedWorkspaceURL: presentation.workspaceURL,
          expectedSessionFileURL: presentation.session.fileURL,
          onWorkspaceMutation: onWorkspaceMutation
        )

        if !Task.isCancelled {
          onDeleted(presentation.session.id)
        }
      } catch {
        guard !Task.isCancelled else {
          return
        }

        actionErrorMessage = error.localizedDescription
      }

      deleteTask = nil
    }
  }

  /// Clears editor, deletion, and error state when the workspace changes.
  func reset() {
    draftLoadTask?.cancel()
    draftLoadTask = nil
    deleteTask?.cancel()
    deleteTask = nil
    editorPresentation = nil
    pendingDeletion = nil
    isLoadingDraft = false
    actionErrorMessage = nil
  }

  /// Creates a prefilled draft for new-session creation.
  func defaultSessionDraft(snapshot: WorkspaceSnapshot) -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: "",
      personaId: snapshot.personas.first?.id ?? "",
      directiveId: snapshot.directives.first?.id ?? "",
      kitOverrides: []
    )
  }

  /// Loads an editable session draft from an existing on-disk session file.
  func loadSessionDraft(for session: WorkspaceSessionListItem) async throws -> WorkspaceSessionDraft {
    try await operationRunner.loadSessionDraft(fileURL: session.fileURL)
  }

  /// Saves a session draft to project scope and refreshes workspace data.
  func saveSession(
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    expectedWorkspaceURL: URL?,
    expectedOriginalSessionFileURL: URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async throws -> String {
    let workspaceURL = try requiredWorkspaceURL(workspaceURL)

    try validateExpectedWorkspace(
      expectedWorkspaceURL,
      currentWorkspaceURL: workspaceURL
    )
    try validateExpectedSessionFile(
      expectedOriginalSessionFileURL,
      sessionID: originalSessionID,
      snapshot: snapshot
    )

    let sessionID = try await operationRunner.saveSession(
      workspaceURL: workspaceURL,
      draft: draft,
      originalSessionID: originalSessionID,
      validPersonaIDs: Set(snapshot.personas.map(\.id)),
      validDirectiveIDs: Set(snapshot.directives.map(\.id)),
      validKitIDs: Set(snapshot.kits.map(\.id))
    )

    actionErrorMessage = nil
    onWorkspaceMutation()
    return sessionID
  }

  /// Deletes a project-scoped session file and refreshes workspace data.
  func deleteSession(
    sessionID: String,
    workspaceURL: URL?,
    snapshot: WorkspaceSnapshot,
    expectedWorkspaceURL: URL?,
    expectedSessionFileURL: URL?,
    onWorkspaceMutation: @MainActor () -> Void
  ) async throws {
    let workspaceURL = try requiredWorkspaceURL(workspaceURL)

    try validateExpectedWorkspace(
      expectedWorkspaceURL,
      currentWorkspaceURL: workspaceURL
    )
    try validateExpectedSessionFile(
      expectedSessionFileURL,
      sessionID: sessionID,
      snapshot: snapshot
    )

    try await operationRunner.deleteSession(
      workspaceURL: workspaceURL,
      sessionID: sessionID
    )

    onWorkspaceMutation()
  }

  private func requiredWorkspaceURL(_ workspaceURL: URL?) throws -> URL {
    guard let workspaceURL else {
      throw WorkspaceSnapshotBuildError(
        message: "No workspace is currently selected."
      )
    }

    return workspaceURL.standardizedFileURL
  }

  private func validateExpectedWorkspace(
    _ expectedWorkspaceURL: URL?,
    currentWorkspaceURL: URL
  ) throws {
    guard let expectedWorkspaceURL else {
      return
    }

    guard expectedWorkspaceURL.standardizedFileURL == currentWorkspaceURL.standardizedFileURL else {
      throw staleSessionSelectionError()
    }
  }

  private func validateExpectedSessionFile(
    _ expectedSessionFileURL: URL?,
    sessionID: String?,
    snapshot: WorkspaceSnapshot
  ) throws {
    guard let expectedSessionFileURL else {
      return
    }

    guard let sessionID,
      snapshot.sessions.contains(where: { session in
        session.id == sessionID
          && session.sourceScope == .project
          && session.fileURL.standardizedFileURL == expectedSessionFileURL.standardizedFileURL
      })
    else {
      throw staleSessionSelectionError()
    }
  }

  private func staleSessionSelectionError() -> WorkspaceSnapshotBuildError {
    WorkspaceSnapshotBuildError(
      message: "Selected session is no longer available in the current workspace. Reload the workspace and try again."
    )
  }
}
