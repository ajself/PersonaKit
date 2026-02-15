import Foundation
import Observation
import PersonaKitCore

/// Raw JSON editor payload used by Studio library editing flows.
struct WorkspaceLibraryEditorPresentation: Equatable, Identifiable, Sendable {
  let itemID: String
  let entityType: WorkspaceLibraryEntityType
  let fileURL: URL
  let rawJSON: String
  let workspaceURL: URL

  var id: String {
    "\(workspaceURL.path())::\(entityType.rawValue)::\(itemID)"
  }
}

/// Markdown editor payload used by Studio essentials editing flows.
struct WorkspaceEssentialEditorPresentation: Equatable, Identifiable, Sendable {
  let fileURL: URL
  let itemID: String
  let markdown: String
  let workspaceURL: URL

  var id: String {
    "\(workspaceURL.path())::\(itemID)"
  }
}

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
final class WorkspaceStore {
  var workspaceURL: URL?
  var snapshot: WorkspaceSnapshot = .empty
  var loadErrorMessage: String?
  var canInitializeWorkspaceStructure = false
  var validation: WorkspaceValidationSnapshot = .empty
  var validationErrorMessage: String?
  var sessionPreview: String = ""
  var sessionPreviewErrorMessage: String?
  var isLoadingSessionPreview = false
  var libraryActionMessage: String?
  var libraryActionIsError = false
  var isLoadingLibraryEditor = false

  private let operationRunner: WorkspaceOperationRunner
  private let workspacePicker: any WorkspacePicking
  private let workspaceInitializer: WorkspaceInitializer
  private let previewExportDestinationPicker: any PreviewExportDestinationPicking
  private let pasteboardWriter: any PasteboardWriting
  private var loadTask: Task<Void, Never>?
  private var validationTask: Task<Void, Never>?
  private var sessionPreviewTask: Task<Void, Never>?
  private var previewSessionID: String?
  private var libraryActionRequestID: Int = 0

  init(
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
    pasteboardWriter: any PasteboardWriting = PasteboardClient()
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

    self.operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager,
      essentialManager: resolvedEssentialManager,
      libraryEntityManager: resolvedLibraryEntityManager,
      sessionPreviewManager: resolvedSessionPreviewManager
    )
    self.workspacePicker = workspacePicker
    self.workspaceInitializer = workspaceInitializer
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
    invalidateLibraryActionRequests()

    guard let workspaceURL else {
      loadTask?.cancel()
      validationTask?.cancel()
      clearSessionPreview()
      snapshot = .empty
      loadErrorMessage = nil
      canInitializeWorkspaceStructure = false
      validation = .empty
      validationErrorMessage = nil
      resetLibraryActionState()
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
      validDirectiveIDs: Set(snapshot.directives.map(\.id)),
      validKitIDs: Set(snapshot.kits.map(\.id))
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

  /// Loads raw JSON for a selected project-scoped library item.
  func openLibraryEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> WorkspaceLibraryEditorPresentation? {
    guard let selectedItem else {
      return nil
    }

    guard let entityType else {
      setLibraryAction(
        message: "Raw JSON editing is not available for this category.",
        isError: true
      )
      return nil
    }

    guard selectedItem.sourceScope == .project else {
      setLibraryAction(
        message: "Global items are read-only. Use Copy to Project first.",
        isError: true
      )
      return nil
    }

    guard
      let projectItem = libraryItemFromSnapshot(
        matching: selectedItem,
        entityType: entityType,
        sourceScope: .project
      )
    else {
      setLibraryAction(
        message:
          "Selected item is not a project library entity in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return nil
    }

    guard let requestWorkspaceURL = workspaceURL?.standardizedFileURL else {
      setLibraryAction(
        message: "No workspace is currently selected.",
        isError: true
      )
      return nil
    }

    let requestID = beginLibraryActionRequest()

    do {
      let rawJSON = try await operationRunner.loadLibraryItemRawJSON(fileURL: projectItem.fileURL)

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      return WorkspaceLibraryEditorPresentation(
        itemID: projectItem.id,
        entityType: entityType,
        fileURL: projectItem.fileURL.standardizedFileURL,
        rawJSON: rawJSON,
        workspaceURL: requestWorkspaceURL
      )
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )

      return nil
    }
  }

  /// Loads markdown for a selected project-scoped essential.
  func openEssentialEditor(
    selectedItem: WorkspaceListItem?
  ) async -> WorkspaceEssentialEditorPresentation? {
    guard let selectedItem else {
      return nil
    }

    guard selectedItem.sourceScope == .project else {
      setLibraryAction(
        message: "Global essentials are read-only. Use Copy to Project first.",
        isError: true
      )
      return nil
    }

    guard
      let projectEssential = essentialItemFromSnapshot(
        matching: selectedItem,
        sourceScope: .project
      )
    else {
      setLibraryAction(
        message:
          "Selected item is not a project essential in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return nil
    }

    guard let requestWorkspaceURL = workspaceURL?.standardizedFileURL else {
      setLibraryAction(
        message: "No workspace is currently selected.",
        isError: true
      )
      return nil
    }

    let requestID = beginLibraryActionRequest()

    do {
      let markdown = try await operationRunner.loadEssentialMarkdown(fileURL: projectEssential.fileURL)

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      return WorkspaceEssentialEditorPresentation(
        fileURL: projectEssential.fileURL.standardizedFileURL,
        itemID: projectEssential.id,
        markdown: markdown,
        workspaceURL: requestWorkspaceURL
      )
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )

      return nil
    }
  }

  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    do {
      try await operationRunner.validateLibraryItemRawJSON(
        rawJSON,
        itemID: presentation.itemID,
        entityType: presentation.entityType
      )

      return nil
    } catch {
      return error.localizedDescription
    }
  }

  /// Saves markdown from the essentials editor and returns an optional error message.
  func saveEssentialEditorMarkdown(
    _ markdown: String,
    presentation: WorkspaceEssentialEditorPresentation
  ) async -> String? {
    guard let currentWorkspaceURL = workspaceURL?.standardizedFileURL else {
      let message = "No workspace is currently selected."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    guard currentWorkspaceURL == presentation.workspaceURL.standardizedFileURL else {
      let message =
        "Workspace changed while this editor was open. Close and reopen the editor before saving."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    guard
      let projectEssential = projectEssentialItem(
        id: presentation.itemID,
        fileURL: presentation.fileURL
      )
    else {
      let message =
        "Selected essential is not available in project scope. Reload the workspace and try again."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    let requestID = beginLibraryActionRequest()
    let requestWorkspaceURL = currentWorkspaceURL

    do {
      try await operationRunner.saveEssentialMarkdown(
        workspaceURL: currentWorkspaceURL,
        itemID: projectEssential.id,
        markdown: markdown
      )

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: "Saved \(projectEssential.id).",
        isError: false
      )

      loadWorkspace()
      return nil
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )

      return error.localizedDescription
    }
  }

  /// Saves raw JSON from the library editor and returns an optional error message.
  func saveLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    guard let currentWorkspaceURL = workspaceURL?.standardizedFileURL else {
      let message = "No workspace is currently selected."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    guard currentWorkspaceURL == presentation.workspaceURL.standardizedFileURL else {
      let message =
        "Workspace changed while this editor was open. Close and reopen the editor before saving."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    guard
      let projectItem = projectLibraryItem(
        itemID: presentation.itemID,
        fileURL: presentation.fileURL,
        entityType: presentation.entityType
      )
    else {
      let message =
        "Selected item is not available in project scope. Reload the workspace and try again."

      setLibraryAction(
        message: message,
        isError: true
      )

      return message
    }

    let requestID = beginLibraryActionRequest()
    let requestWorkspaceURL = currentWorkspaceURL

    do {
      try await operationRunner.saveLibraryItemRawJSON(
        workspaceURL: currentWorkspaceURL,
        itemID: projectItem.id,
        rawJSON: rawJSON,
        entityType: presentation.entityType
      )

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: "Saved \(projectItem.id).",
        isError: false
      )

      loadWorkspace()
      return nil
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return nil
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )

      return error.localizedDescription
    }
  }

  /// Copies a selected global library item into project scope and updates status state.
  func copySelectedGlobalLibraryItem(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> Bool {
    guard let selectedItem else {
      return false
    }

    guard let entityType else {
      setLibraryAction(
        message: "Raw JSON copy is not available for this category.",
        isError: true
      )
      return false
    }

    guard selectedItem.sourceScope == .global else {
      setLibraryAction(
        message: "Copy to Project is only available for global items.",
        isError: true
      )
      return false
    }

    guard
      let globalItem = libraryItemFromSnapshot(
        matching: selectedItem,
        entityType: entityType,
        sourceScope: .global
      )
    else {
      setLibraryAction(
        message:
          "Selected item is not a global library entity in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return false
    }

    let requestID = beginLibraryActionRequest()
    let requestWorkspaceURL = workspaceURL

    do {
      let workspaceURL = try requiredWorkspaceURL()

      try await operationRunner.copyLibraryItemToProject(
        workspaceURL: workspaceURL,
        item: globalItem,
        entityType: entityType
      )

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return false
      }

      setLibraryAction(
        message: "Copied \(globalItem.id) to project scope.",
        isError: false
      )

      loadWorkspace()
      return true
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return false
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )
      return false
    }
  }

  /// Copies a selected global essential into project scope and updates status state.
  func copySelectedGlobalEssentialToProject(
    selectedItem: WorkspaceListItem?
  ) async -> Bool {
    guard let selectedItem else {
      return false
    }

    guard selectedItem.sourceScope == .global else {
      setLibraryAction(
        message: "Copy to Project is only available for global essentials.",
        isError: true
      )
      return false
    }

    guard
      let globalEssential = essentialItemFromSnapshot(
        matching: selectedItem,
        sourceScope: .global
      )
    else {
      setLibraryAction(
        message:
          "Selected item is not a global essential in the current snapshot. Reload the workspace and try again.",
        isError: true
      )
      return false
    }

    let requestID = beginLibraryActionRequest()
    let requestWorkspaceURL = workspaceURL

    do {
      let workspaceURL = try requiredWorkspaceURL()

      try await operationRunner.copyGlobalEssentialToProject(
        workspaceURL: workspaceURL,
        item: globalEssential
      )

      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return false
      }

      setLibraryAction(
        message: "Copied \(globalEssential.id) to project scope.",
        isError: false
      )

      loadWorkspace()
      return true
    } catch {
      guard completeLibraryActionRequest(requestID: requestID, workspaceURL: requestWorkspaceURL) else {
        return false
      }

      setLibraryAction(
        message: error.localizedDescription,
        isError: true
      )
      return false
    }
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
    let snapshotAtValidationStart = self.snapshot

    validationTask = Task { [workspaceURL, snapshotAtValidationStart] in
      do {
        let validation = try await operationRunner.validate(
          workspaceURL: workspaceURL,
          snapshot: snapshotAtValidationStart
        )

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

  private func essentialItemFromSnapshot(
    matching selectedItem: WorkspaceListItem,
    sourceScope: WorkspaceSourceScope
  ) -> WorkspaceListItem? {
    let selectedFileURL = selectedItem.fileURL.standardizedFileURL

    return snapshot.essentials.first { item in
      item.id == selectedItem.id
        && item.sourceScope == sourceScope
        && item.fileURL.standardizedFileURL == selectedFileURL
    }
  }

  private func projectEssentialItem(
    id: String,
    fileURL: URL
  ) -> WorkspaceListItem? {
    let standardizedFileURL = fileURL.standardizedFileURL

    return snapshot.essentials.first { item in
      item.id == id
        && item.sourceScope == .project
        && item.fileURL.standardizedFileURL == standardizedFileURL
    }
  }

  private func libraryItemFromSnapshot(
    matching selectedItem: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType,
    sourceScope: WorkspaceSourceScope
  ) -> WorkspaceListItem? {
    let selectedFileURL = selectedItem.fileURL.standardizedFileURL

    return libraryItems(for: entityType).first { item in
      item.id == selectedItem.id
        && item.sourceScope == sourceScope
        && item.fileURL.standardizedFileURL == selectedFileURL
    }
  }

  private func projectLibraryItem(
    itemID: String,
    fileURL: URL,
    entityType: WorkspaceLibraryEntityType
  ) -> WorkspaceListItem? {
    let standardizedFileURL = fileURL.standardizedFileURL

    return libraryItems(for: entityType).first { item in
      item.id == itemID
        && item.sourceScope == .project
        && item.fileURL.standardizedFileURL == standardizedFileURL
    }
  }

  private func libraryItems(
    for entityType: WorkspaceLibraryEntityType
  ) -> [WorkspaceListItem] {
    switch entityType {
    case .directive:
      return snapshot.directives
    case .intent:
      return snapshot.intents
    case .kit:
      return snapshot.kits
    case .persona:
      return snapshot.personas
    case .skill:
      return snapshot.skills
    }
  }

  private func beginLibraryActionRequest() -> Int {
    libraryActionRequestID += 1
    isLoadingLibraryEditor = true
    libraryActionMessage = nil
    libraryActionIsError = false

    return libraryActionRequestID
  }

  private func completeLibraryActionRequest(
    requestID: Int,
    workspaceURL: URL?
  ) -> Bool {
    guard libraryActionRequestID == requestID else {
      return false
    }

    guard self.workspaceURL == workspaceURL else {
      return false
    }

    isLoadingLibraryEditor = false
    return true
  }

  private func invalidateLibraryActionRequests() {
    libraryActionRequestID += 1
    isLoadingLibraryEditor = false
  }

  private func resetLibraryActionState() {
    libraryActionMessage = nil
    libraryActionIsError = false
    isLoadingLibraryEditor = false
  }

  private func setLibraryAction(
    message: String,
    isError: Bool
  ) {
    libraryActionMessage = message
    libraryActionIsError = isError
  }
}

private actor WorkspaceOperationRunner {
  private let snapshotBuilder: any WorkspaceSnapshotBuilding
  private let workspaceValidator: any WorkspaceValidating
  private let sessionManager: any WorkspaceSessionManaging
  private let essentialManager: any WorkspaceEssentialManaging
  private let libraryEntityManager: any WorkspaceLibraryEntityManaging
  private let sessionPreviewManager: any WorkspaceSessionPreviewManaging

  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding,
    workspaceValidator: any WorkspaceValidating,
    sessionManager: any WorkspaceSessionManaging,
    essentialManager: any WorkspaceEssentialManaging,
    libraryEntityManager: any WorkspaceLibraryEntityManaging,
    sessionPreviewManager: any WorkspaceSessionPreviewManaging
  ) {
    self.snapshotBuilder = snapshotBuilder
    self.workspaceValidator = workspaceValidator
    self.sessionManager = sessionManager
    self.essentialManager = essentialManager
    self.libraryEntityManager = libraryEntityManager
    self.sessionPreviewManager = sessionPreviewManager
  }

  func loadSnapshot(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try snapshotBuilder.build(workspaceURL: workspaceURL)
  }

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try workspaceValidator.validate(workspaceURL: workspaceURL)
  }

  func validate(
    workspaceURL: URL,
    snapshot: WorkspaceSnapshot
  ) throws -> WorkspaceValidationSnapshot {
    let coreValidation = try workspaceValidator.validate(workspaceURL: workspaceURL)
    let sessionIssues = WorkspaceSessionDiagnostics.validateSessions(
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )

    return WorkspaceValidationSnapshot(
      summary: coreValidation.summary,
      issues: coreValidation.issues + sessionIssues
    )
  }

  func loadSessionDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try sessionManager.loadDraft(fileURL: fileURL)
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    try sessionManager.saveSession(
      workspaceURL: workspaceURL,
      draft: draft,
      originalSessionID: originalSessionID,
      validPersonaIDs: validPersonaIDs,
      validDirectiveIDs: validDirectiveIDs,
      validKitIDs: validKitIDs
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

  func loadEssentialMarkdown(fileURL: URL) throws -> String {
    try essentialManager.loadMarkdown(fileURL: fileURL)
  }

  func saveEssentialMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {
    try essentialManager.saveMarkdown(
      workspaceURL: workspaceURL,
      itemID: itemID,
      markdown: markdown
    )
  }

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {
    try essentialManager.copyGlobalEssentialToProject(
      workspaceURL: workspaceURL,
      item: item
    )
  }

  func loadLibraryItemRawJSON(fileURL: URL) throws -> String {
    try libraryEntityManager.loadRawJSON(fileURL: fileURL)
  }

  func validateLibraryItemRawJSON(
    _ rawJSON: String,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.validateRawJSON(
      rawJSON,
      entityType: entityType,
      expectedID: itemID
    )
  }

  func saveLibraryItemRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.saveRawJSON(
      workspaceURL: workspaceURL,
      itemID: itemID,
      rawJSON: rawJSON,
      entityType: entityType
    )
  }

  func copyLibraryItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.copyGlobalItemToProject(
      workspaceURL: workspaceURL,
      item: item,
      entityType: entityType
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
