import ContextCore
import Foundation
import Observation
import StudioFoundation

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
public final class WorkspaceStore {
  var workspaceURL: URL?
  var snapshot: WorkspaceSnapshot = .empty
  var loadErrorMessage: String?
  var canInitializeWorkspaceStructure = false
  var validation: WorkspaceValidationSnapshot {
    get {
      validationFeatureModel.validation
    }

    set {
      validationFeatureModel.validation = newValue
    }
  }

  var validationErrorMessage: String? {
    get {
      validationFeatureModel.validationErrorMessage
    }

    set {
      validationFeatureModel.validationErrorMessage = newValue
    }
  }
  var sessionPreview: String {
    get {
      sessionFeatureModel.preview
    }

    set {
      sessionFeatureModel.preview = newValue
    }
  }

  var sessionPreviewErrorMessage: String? {
    sessionFeatureModel.previewErrorMessage
  }

  var isLoadingSessionPreview: Bool {
    sessionFeatureModel.isLoadingPreview
  }
  var libraryActionMessage: String? {
    libraryFeatureModel.actionMessage
  }

  var libraryActionIsError: Bool {
    libraryFeatureModel.actionIsError
  }

  var isLoadingLibraryEditor: Bool {
    libraryFeatureModel.isLoadingEditor
  }

  private let operationRunner: WorkspaceOperationRunner
  private let libraryFeatureModel: WorkspaceLibraryFeatureModel
  private let sessionEditorFeatureModel: WorkspaceSessionEditorFeatureModel
  private let sessionFeatureModel: WorkspaceSessionFeatureModel
  private let validationFeatureModel: WorkspaceValidationFeatureModel
  private let workspacePicker: any WorkspacePicking
  private let workspaceInitializer: WorkspaceInitializer
  private let fileRevealer: any FileRevealing
  private var loadTask: Task<Void, Never>?

  public init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager(),
    essentialManager: (any WorkspaceEssentialManaging)? = nil,
    libraryEntityManager: (any WorkspaceLibraryEntityManaging)? = nil,
    sessionPreviewManager: (any WorkspaceSessionPreviewManaging)? = nil,
    workspaceInitializer: WorkspaceInitializer = WorkspaceInitializer(),
    workspacePicker: any WorkspacePicking = WorkspacePickerClient(),
    previewExportDestinationPicker: any PreviewExportDestinationPicking =
      PreviewExportDestinationPickerClient(),
    pasteboardWriter: any PasteboardWriting = PasteboardClient(),
    fileRevealer: any FileRevealing = FileRevealerClient()
  ) {
    let resolvedEssentialManager =
      essentialManager
      ?? WorkspaceEssentialManager()

    let resolvedLibraryEntityManager =
      libraryEntityManager
      ?? WorkspaceLibraryEntityManager()

    let resolvedSessionPreviewManager =
      sessionPreviewManager
      ?? WorkspaceSessionPreviewManager(sessionManager: sessionManager)

    let operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager,
      essentialManager: resolvedEssentialManager,
      libraryEntityManager: resolvedLibraryEntityManager,
      sessionPreviewManager: resolvedSessionPreviewManager
    )
    self.operationRunner = operationRunner
    self.workspacePicker = workspacePicker
    self.workspaceInitializer = workspaceInitializer
    self.fileRevealer = fileRevealer
    self.libraryFeatureModel = WorkspaceLibraryFeatureModel(operationRunner: operationRunner)
    self.sessionEditorFeatureModel = WorkspaceSessionEditorFeatureModel(
      operationRunner: operationRunner
    )
    self.sessionFeatureModel = WorkspaceSessionFeatureModel(
      operationRunner: operationRunner,
      previewExportDestinationPicker: previewExportDestinationPicker,
      pasteboardWriter: pasteboardWriter
    )
    self.validationFeatureModel = WorkspaceValidationFeatureModel(
      operationRunner: operationRunner
    )
  }

  /// Presents the folder picker and loads the selected workspace snapshot.
  public func openWorkspacePicker() {
    guard let selectedURL = workspacePicker.pickWorkspaceURL() else {
      return
    }

    workspaceURL = selectedURL.standardizedFileURL
    loadWorkspace()
  }

  /// Creates a minimal PersonaKit folder structure at the selected workspace and reloads state.
  func initializeWorkspaceStructure() {
    guard let workspaceURL else {
      return
    }

    do {
      try workspaceInitializer.initialize(
        at: workspaceURL
      )

      loadWorkspace()
    } catch {
      loadErrorMessage =
        "Failed to initialize PersonaKit structure: \(error.localizedDescription)"
      canInitializeWorkspaceStructure = false
    }
  }

  /// Reloads workspace data into the current snapshot and error state.
  func loadWorkspace() {
    libraryFeatureModel.invalidateRequests()

    guard let workspaceURL else {
      loadTask?.cancel()
      validationFeatureModel.cancelValidationTask()
      clearSessionPreview()
      snapshot = .empty
      loadErrorMessage = nil
      canInitializeWorkspaceStructure = false
      validation = .empty
      validationErrorMessage = nil
      libraryFeatureModel.resetState()
      return
    }

    loadTask?.cancel()
    validationFeatureModel.cancelValidationTask()
    sessionFeatureModel.cancelPreviewTask()

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
        canInitializeWorkspaceStructure = false
        validation = .empty
        validationErrorMessage = nil
        restoreSessionPreviewIfPossible()
        runValidationTask(for: workspaceURL)
      } catch let error as MissingPersonaKitDirectoryError {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        snapshot = .empty
        loadErrorMessage = error.localizedDescription
        canInitializeWorkspaceStructure = true
        validation = .empty
        validationErrorMessage = nil
        clearSessionPreview()
      } catch let error as WorkspaceSnapshotBuildError {
        guard !Task.isCancelled,
          self.workspaceURL == workspaceURL
        else {
          return
        }

        snapshot = .empty
        loadErrorMessage = error.message
        canInitializeWorkspaceStructure = false
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
        canInitializeWorkspaceStructure = false
        validation = .empty
        validationErrorMessage = nil
        clearSessionPreview()
      }
    }
  }

  /// Runs validator checks and refreshes diagnostics state.
  func validateWorkspace() {
    guard let workspaceURL else {
      validationFeatureModel.cancelValidationTask()
      validationFeatureModel.reset()
      return
    }

    runValidationTask(for: workspaceURL)
  }

  /// Creates a prefilled draft for new-session creation.
  func defaultSessionDraft() -> WorkspaceSessionDraft {
    sessionEditorFeatureModel.defaultSessionDraft(
      snapshot: snapshot
    )
  }

  /// Loads an editable session draft from an existing on-disk session file.
  func loadSessionDraft(
    for session: WorkspaceSessionListItem
  ) async throws -> WorkspaceSessionDraft {
    try await sessionEditorFeatureModel.loadSessionDraft(
      for: session
    )
  }

  /// Saves a session draft to project scope and refreshes workspace data.
  func saveSession(
    draft: WorkspaceSessionDraft,
    originalSessionID: String?
  ) async throws -> String {
    try await sessionEditorFeatureModel.saveSession(
      draft: draft,
      originalSessionID: originalSessionID,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Deletes a project-scoped session file and refreshes workspace data.
  func deleteSession(sessionID: String) async throws {
    try await sessionEditorFeatureModel.deleteSession(
      sessionID: sessionID,
      workspaceURL: workspaceURL,
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Loads raw JSON for a selected project-scoped library item.
  func openLibraryEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> WorkspaceLibraryEditorPresentation? {
    await libraryFeatureModel.openLibraryEditor(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL }
    )
  }

  /// Loads markdown for a selected project-scoped essential.
  func openEssentialEditor(
    selectedItem: WorkspaceListItem?
  ) async -> WorkspaceEssentialEditorPresentation? {
    await libraryFeatureModel.openEssentialEditor(
      selectedItem: selectedItem,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL }
    )
  }

  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    await libraryFeatureModel.validateLibraryEditorRawJSON(
      rawJSON,
      presentation: presentation
    )
  }

  /// Saves markdown from the essentials editor and returns an optional error message.
  func saveEssentialEditorMarkdown(
    _ markdown: String,
    presentation: WorkspaceEssentialEditorPresentation
  ) async -> String? {
    await libraryFeatureModel.saveEssentialEditorMarkdown(
      markdown,
      presentation: presentation,
      snapshot: snapshot,
      currentWorkspaceURLProvider: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Saves raw JSON from the library editor and returns an optional error message.
  func saveLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    await libraryFeatureModel.saveLibraryEditorRawJSON(
      rawJSON,
      presentation: presentation,
      snapshot: snapshot,
      currentWorkspaceURLProvider: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Copies a selected global library item into project scope and updates status state.
  func copySelectedGlobalLibraryItem(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> Bool {
    await libraryFeatureModel.copySelectedGlobalLibraryItem(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Copies a selected global essential into project scope and updates status state.
  func copySelectedGlobalEssentialToProject(
    selectedItem: WorkspaceListItem?
  ) async -> Bool {
    await libraryFeatureModel.copySelectedGlobalEssentialToProject(
      selectedItem: selectedItem,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Loads markdown preview text for the selected session.
  func refreshSessionPreview(
    for session: WorkspaceSessionListItem?
  ) {
    sessionFeatureModel.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )
  }

  /// Copies the current preview text into the system pasteboard.
  func copySessionPreviewToPasteboard() throws {
    try sessionFeatureModel.copyPreviewToPasteboard()
  }

  /// Presents a save panel and exports preview markdown to the selected path.
  func exportSessionPreviewWithSavePanel() async throws -> Bool {
    try await sessionFeatureModel.exportPreviewWithSavePanel()
  }

  /// Reveals a file in Finder.
  func revealInFinder(fileURL: URL) {
    fileRevealer.reveal(fileURL.standardizedFileURL)
  }

  /// Resolves a diagnostics file path and reveals the resulting URL in Finder when possible.
  func revealValidationIssueInFinder(filePath: String) {
    guard
      let fileURL = WorkspaceSnapshotLookup.resolveValidationIssueFileURL(
        filePath,
        workspaceURL: workspaceURL,
        snapshot: snapshot
      )
    else {
      return
    }

    fileRevealer.reveal(fileURL)
  }

  private func runValidationTask(for workspaceURL: URL) {
    validationFeatureModel.runValidation(
      workspaceURL: workspaceURL,
      snapshotAtValidationStart: snapshot
    )
  }

  private func clearSessionPreview() {
    sessionFeatureModel.clearPreview()
  }

  private func restoreSessionPreviewIfPossible() {
    sessionFeatureModel.restorePreviewIfPossible(
      snapshot: snapshot,
      workspaceURL: workspaceURL
    )
  }

}
