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
  var sessionPreview: String = ""
  var sessionPreviewErrorMessage: String?
  var isLoadingSessionPreview = false

  private let operationRunner: WorkspaceOperationRunner
  private let workspacePicker: any WorkspacePicking
  private let previewExportDestinationPicker: any PreviewExportDestinationPicking
  private let pasteboardWriter: any PasteboardWriting
  private var loadTask: Task<Void, Never>?
  private var validationTask: Task<Void, Never>?
  private var sessionPreviewTask: Task<Void, Never>?
  private var previewSessionID: String?

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager(),
    sessionPreviewManager: (any WorkspaceSessionPreviewManaging)? = nil,
    workspacePicker: any WorkspacePicking = WorkspacePickerClient(),
    previewExportDestinationPicker: any PreviewExportDestinationPicking =
      PreviewExportDestinationPickerClient(),
    pasteboardWriter: any PasteboardWriting = PasteboardClient()
  ) {
    let resolvedSessionPreviewManager =
      sessionPreviewManager
      ?? WorkspaceSessionPreviewManager(sessionManager: sessionManager)

    self.operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager,
      sessionPreviewManager: resolvedSessionPreviewManager
    )
    self.workspacePicker = workspacePicker
    self.previewExportDestinationPicker = previewExportDestinationPicker
    self.pasteboardWriter = pasteboardWriter
  }

  /// Presents the folder picker and loads the selected workspace snapshot.
  func openWorkspacePicker() {
    guard let selectedURL = workspacePicker.pickWorkspaceURL() else {
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
      clearSessionPreview()
      snapshot = .empty
      loadErrorMessage = nil
      validation = .empty
      validationErrorMessage = nil
      return
    }

    loadTask?.cancel()
    validationTask?.cancel()
    sessionPreviewTask?.cancel()

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
        restoreSessionPreviewIfPossible()
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
        clearSessionPreview()
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
        clearSessionPreview()
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

  /// Loads markdown preview text for the selected session.
  func refreshSessionPreview(
    for session: WorkspaceSessionListItem?
  ) {
    sessionPreviewTask?.cancel()

    guard let session else {
      clearSessionPreview()
      return
    }

    guard let workspaceURL else {
      clearSessionPreview()
      return
    }

    previewSessionID = session.id
    sessionPreview = ""
    sessionPreviewErrorMessage = nil
    isLoadingSessionPreview = true

    sessionPreviewTask = Task { [workspaceURL, session] in
      do {
        let preview = try await operationRunner.loadSessionPreview(
          workspaceURL: workspaceURL,
          session: session
        )

        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL,
          previewSessionID == session.id
        else {
          return
        }

        sessionPreview = preview
        sessionPreviewErrorMessage = nil
        isLoadingSessionPreview = false
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL,
          previewSessionID == session.id
        else {
          return
        }

        sessionPreview = ""
        sessionPreviewErrorMessage = error.message
        isLoadingSessionPreview = false
      } catch {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL,
          previewSessionID == session.id
        else {
          return
        }

        sessionPreview = ""
        sessionPreviewErrorMessage = error.localizedDescription
        isLoadingSessionPreview = false
      }
    }
  }

  /// Copies the current preview text into the system pasteboard.
  func copySessionPreviewToPasteboard() throws {
    guard !sessionPreview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No preview is available to copy."
      )
    }

    guard pasteboardWriter.writeString(sessionPreview) else {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to copy preview to the clipboard."
      )
    }
  }

  /// Presents a save panel and exports preview markdown to the selected path.
  func exportSessionPreviewWithSavePanel() async throws -> Bool {
    guard !sessionPreview.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "No preview is available to export."
      )
    }

    guard
      let destinationURL = previewExportDestinationPicker.pickPreviewDestination(
        suggestedFilename: defaultPreviewFilename()
      )
    else {
      return false
    }

    try await operationRunner.exportSessionPreview(
      sessionPreview,
      to: destinationURL
    )

    return true
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

  private func clearSessionPreview() {
    sessionPreviewTask?.cancel()
    sessionPreviewTask = nil
    previewSessionID = nil
    sessionPreview = ""
    sessionPreviewErrorMessage = nil
    isLoadingSessionPreview = false
  }

  private func restoreSessionPreviewIfPossible() {
    guard let previewSessionID,
      let session = snapshot.sessions.first(where: { $0.id == previewSessionID })
    else {
      clearSessionPreview()
      return
    }

    refreshSessionPreview(for: session)
  }

  private func defaultPreviewFilename() -> String {
    guard let previewSessionID else {
      return "session-preview.md"
    }

    return "\(previewSessionID).md"
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
  private let sessionPreviewManager: any WorkspaceSessionPreviewManaging

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding,
    workspaceValidator: any WorkspaceValidating,
    sessionManager: any WorkspaceSessionManaging,
    sessionPreviewManager: any WorkspaceSessionPreviewManaging
  ) {
    self.snapshotBuilder = snapshotBuilder
    self.workspaceValidator = workspaceValidator
    self.sessionManager = sessionManager
    self.sessionPreviewManager = sessionPreviewManager
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

  func loadSessionPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    try sessionPreviewManager.loadPreview(
      workspaceURL: workspaceURL,
      session: session
    )
  }

  func exportSessionPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {
    try sessionPreviewManager.exportPreview(
      preview,
      to: destinationURL
    )
  }
}
