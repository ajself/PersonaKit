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

  private let loadFeatureModel: WorkspaceLoadFeatureModel
  private let systemFeatureModel: WorkspaceSystemFeatureModel
  private let libraryFeatureModel: WorkspaceLibraryFeatureModel
  private let sessionEditorFeatureModel: WorkspaceSessionEditorFeatureModel
  private let sessionFeatureModel: WorkspaceSessionFeatureModel
  private let validationFeatureModel: WorkspaceValidationFeatureModel

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
    self.loadFeatureModel = WorkspaceLoadFeatureModel(operationRunner: operationRunner)
    self.systemFeatureModel = WorkspaceSystemFeatureModel(
      workspacePicker: workspacePicker,
      workspaceInitializer: workspaceInitializer,
      fileRevealer: fileRevealer
    )
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
    guard let selectedURL = systemFeatureModel.pickWorkspaceURL() else {
      return
    }

    workspaceURL = selectedURL
    loadWorkspace()
  }

  /// Creates a minimal PersonaKit folder structure at the selected workspace and reloads state.
  func initializeWorkspaceStructure() {
    do {
      guard
        try systemFeatureModel.initializeWorkspaceStructure(
          at: workspaceURL
        )
      else {
        return
      }

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
      loadFeatureModel.cancelLoadTask()
      validationFeatureModel.cancelValidationTask()
      sessionFeatureModel.clearPreview()
      snapshot = .empty
      loadErrorMessage = nil
      canInitializeWorkspaceStructure = false
      validation = .empty
      validationErrorMessage = nil
      libraryFeatureModel.resetState()
      return
    }

    loadFeatureModel.cancelLoadTask()
    validationFeatureModel.cancelValidationTask()
    sessionFeatureModel.cancelPreviewTask()

    loadFeatureModel.loadWorkspace(
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onLoaded: { [workspaceURL] snapshot in
        self.snapshot = snapshot
        self.loadErrorMessage = nil
        self.canInitializeWorkspaceStructure = false
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.restorePreviewIfPossible(
          snapshot: self.snapshot,
          workspaceURL: self.workspaceURL
        )
        self.validationFeatureModel.runValidation(
          workspaceURL: workspaceURL,
          snapshotAtValidationStart: self.snapshot
        )
      },
      onMissingPersonaKitDirectory: { error in
        self.snapshot = .empty
        self.loadErrorMessage = error.localizedDescription
        self.canInitializeWorkspaceStructure = true
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.clearPreview()
      },
      onLoadFailure: { message in
        self.snapshot = .empty
        self.loadErrorMessage = message
        self.canInitializeWorkspaceStructure = false
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.clearPreview()
      }
    )
  }

  /// Runs validator checks and refreshes diagnostics state.
  func validateWorkspace() {
    guard let workspaceURL else {
      validationFeatureModel.cancelValidationTask()
      validationFeatureModel.reset()
      return
    }

    validationFeatureModel.runValidation(
      workspaceURL: workspaceURL,
      snapshotAtValidationStart: snapshot
    )
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
    systemFeatureModel.revealInFinder(fileURL: fileURL)
  }

  /// Resolves a diagnostics file path and reveals the resulting URL in Finder when possible.
  func revealValidationIssueInFinder(filePath: String) {
    systemFeatureModel.revealValidationIssueInFinder(
      filePath: filePath,
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )
  }

}
