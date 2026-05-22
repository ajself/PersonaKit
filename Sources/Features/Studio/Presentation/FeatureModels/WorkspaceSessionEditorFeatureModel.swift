import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

/// Feature-owned session editor model used by `WorkspaceStore`.
@MainActor
final class WorkspaceSessionEditorFeatureModel {
  private let operationRunner: WorkspaceOperationRunner

  init(operationRunner: WorkspaceOperationRunner) {
    self.operationRunner = operationRunner
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
