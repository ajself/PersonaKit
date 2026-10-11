import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
public final class WorkspaceStore {
  var workspaceURL: URL? {
    didSet {
      let standardizedOldWorkspaceURL = oldValue?.standardizedFileURL

      guard let workspaceURL else {
        guard standardizedOldWorkspaceURL != nil else {
          return
        }

        loadFeatureModel.stopWatching()
        libraryFeatureModel.resetState()
        sessionEditorFeatureModel.reset()
        sessionFeatureModel.clearPreview()
        sessionFeatureModel.clearPreviewActionMessage()
        sessionFeatureModel.clearMap()
        sessionFeatureModel.clearDraftMap()
        return
      }

      let standardizedWorkspaceURL = workspaceURL.standardizedFileURL

      if standardizedWorkspaceURL != workspaceURL {
        self.workspaceURL = standardizedWorkspaceURL
      }

      guard standardizedOldWorkspaceURL != standardizedWorkspaceURL else {
        return
      }

      // The next successful load starts watching the new workspace.
      loadFeatureModel.stopWatching()
      libraryFeatureModel.resetState()
      sessionEditorFeatureModel.reset()
      sessionFeatureModel.clearPreviewActionMessage()
      sessionFeatureModel.clearDraftMap()
    }
  }
  var snapshot: WorkspaceSnapshot = .empty
  var loadErrorMessage: String?
  var canInitializeWorkspaceStructure = false
  var installStatus: WorkspaceInstallStatus
  var installResult: StudioInstallResult?
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
  var sessionMap: WorkspaceSessionMap? {
    sessionFeatureModel.map
  }

  var sessionMapRequestKey: String? {
    sessionFeatureModel.mapRequestKey
  }

  var sessionMapErrorMessage: String? {
    sessionFeatureModel.mapErrorMessage
  }

  var isLoadingSessionMap: Bool {
    sessionFeatureModel.isLoadingMap
  }

  var draftSessionMap: WorkspaceSessionMap? {
    sessionFeatureModel.draftMap
  }

  var draftSessionMapErrorMessage: String? {
    sessionFeatureModel.draftMapErrorMessage
  }

  var isLoadingDraftSessionMap: Bool {
    sessionFeatureModel.isLoadingDraftMap
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

  var libraryRawJSONEditorPresentation: WorkspaceLibraryEditorPresentation? {
    libraryFeatureModel.rawJSONEditorPresentation
  }

  var libraryPersonaEditorPresentation: PersonaEditorPresentation? {
    libraryFeatureModel.personaEditorPresentation
  }

  var libraryDetail: StudioLibraryDetailState {
    libraryFeatureModel.detail
  }

  var libraryUsageLoadFailed: Bool {
    libraryFeatureModel.usageGraphLoadFailed
  }

  /// See ``WorkspaceLibraryFeatureModel/usedBy(kind:id:)``.
  func libraryItemUsers(
    kind: WorkspaceSessionMapNodeKind,
    id: String
  ) -> [WorkspaceSessionMapNode]? {
    libraryFeatureModel.usedBy(kind: kind, id: id)
  }

  var sessionPreviewActionMessage: String? {
    sessionFeatureModel.previewActionMessage
  }

  var sessionEditorPresentation: SessionEditorPresentation? {
    sessionEditorFeatureModel.editorPresentation
  }

  var pendingSessionDeletion: SessionDeletionPresentation? {
    sessionEditorFeatureModel.pendingDeletion
  }

  var isLoadingSessionDraft: Bool {
    sessionEditorFeatureModel.isLoadingDraft
  }

  var sessionActionErrorMessage: String? {
    sessionEditorFeatureModel.actionErrorMessage
  }

  let loadFeatureModel: WorkspaceLoadFeatureModel
  let systemFeatureModel: WorkspaceSystemFeatureModel
  let libraryFeatureModel: WorkspaceLibraryFeatureModel
  let sessionEditorFeatureModel: WorkspaceSessionEditorFeatureModel
  let sessionFeatureModel: WorkspaceSessionFeatureModel
  let validationFeatureModel: WorkspaceValidationFeatureModel
  var recentWorkspacesFeatureModel: StudioRecentWorkspacesFeatureModel
  // Backs the late-bindable global scope read by this store's builders/validator.
  // Non-nil only on the launch-configured path; `setGlobalScope` is a no-op without it.
  let globalScopeProvider: WorkspaceGlobalScopeProvider?
  // Persists/resolves the app-wide global-library grant across launches. Non-nil only on
  // the launch-configured path; the grant flow (S3) persists through it.
  let globalLibraryAccess: StudioGlobalLibraryAccess?
  // Picks the folder to grant as the global library when the user taps Connect (S3).
  let globalLibraryPicker: any GlobalLibraryDirectoryPicking
  // Non-blocking notice shown after a grant whose folder doesn't look like a PersonaKit
  // root (no `Packs/`); cleared on the next connect attempt.
  var globalLibraryConnectWarning: String?

  public convenience init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager(),
    libraryEntityManager: (any WorkspaceLibraryEntityManaging)? = nil,
    sessionPreviewManager: (any WorkspaceSessionPreviewManaging)? = nil,
    sessionMapBuilder: (any WorkspaceSessionMapBuilding)? = nil,
    workspaceRelationshipMapBuilder: (any WorkspaceRelationshipMapBuilding)? = nil,
    workspaceInitializer: WorkspaceInitializer = WorkspaceInitializer(),
    workspacePicker: any WorkspacePicking = WorkspacePickerClient(),
    previewExportDestinationPicker: any PreviewExportDestinationPicking =
      PreviewExportDestinationPickerClient(),
    pasteboardWriter: any PasteboardWriting = PasteboardClient(),
    fileRevealer: any FileRevealing = FileRevealerClient(),
    installEnvironment: any WorkspaceInstallEnvironmentProviding =
      WorkspaceInstallEnvironmentClient(),
    globalScopeProvider: WorkspaceGlobalScopeProvider? = nil,
    globalLibraryAccess: StudioGlobalLibraryAccess? = nil,
    globalLibraryPicker: any GlobalLibraryDirectoryPicking = GlobalLibraryDirectoryPickerClient()
  ) {
    self.init(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager,
      libraryEntityManager: libraryEntityManager,
      sessionPreviewManager: sessionPreviewManager,
      sessionMapBuilder: sessionMapBuilder,
      workspaceRelationshipMapBuilder: workspaceRelationshipMapBuilder,
      workspaceInitializer: workspaceInitializer,
      workspacePicker: workspacePicker,
      previewExportDestinationPicker: previewExportDestinationPicker,
      pasteboardWriter: pasteboardWriter,
      fileRevealer: fileRevealer,
      installEnvironment: installEnvironment,
      globalScopeProvider: globalScopeProvider,
      globalLibraryAccess: globalLibraryAccess,
      globalLibraryPicker: globalLibraryPicker,
      fileEventSource: nil,
      liveReloadClock: ContinuousClock()
    )
  }

  /// Designated initializer; `fileEventSource` enables live reload (nil disables it).
  init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager(),
    libraryEntityManager: (any WorkspaceLibraryEntityManaging)? = nil,
    sessionPreviewManager: (any WorkspaceSessionPreviewManaging)? = nil,
    sessionMapBuilder: (any WorkspaceSessionMapBuilding)? = nil,
    workspaceRelationshipMapBuilder: (any WorkspaceRelationshipMapBuilding)? = nil,
    workspaceInitializer: WorkspaceInitializer = WorkspaceInitializer(),
    workspacePicker: any WorkspacePicking = WorkspacePickerClient(),
    previewExportDestinationPicker: any PreviewExportDestinationPicking =
      PreviewExportDestinationPickerClient(),
    pasteboardWriter: any PasteboardWriting = PasteboardClient(),
    fileRevealer: any FileRevealing = FileRevealerClient(),
    installEnvironment: any WorkspaceInstallEnvironmentProviding =
      WorkspaceInstallEnvironmentClient(),
    globalScopeProvider: WorkspaceGlobalScopeProvider? = nil,
    globalLibraryAccess: StudioGlobalLibraryAccess? = nil,
    globalLibraryPicker: any GlobalLibraryDirectoryPicking = GlobalLibraryDirectoryPickerClient(),
    fileEventSource: (any WorkspaceFileEventStreaming)?,
    liveReloadClock: any Clock<Duration>
  ) {
    self.globalScopeProvider = globalScopeProvider
    self.globalLibraryAccess = globalLibraryAccess
    self.globalLibraryPicker = globalLibraryPicker

    let resolvedLibraryEntityManager =
      libraryEntityManager
      ?? WorkspaceLibraryEntityManager()

    let resolvedSessionPreviewManager =
      sessionPreviewManager
      ?? WorkspaceSessionPreviewManager(sessionManager: sessionManager)
    let resolvedSessionMapBuilder =
      sessionMapBuilder
      ?? WorkspaceSessionMapBuilder()
    let resolvedWorkspaceRelationshipMapBuilder =
      workspaceRelationshipMapBuilder
      ?? WorkspaceRelationshipMapBuilder()

    let operationRunner = WorkspaceOperationRunner(
      snapshotBuilder: snapshotBuilder,
      workspaceValidator: workspaceValidator,
      sessionManager: sessionManager,
      libraryEntityManager: resolvedLibraryEntityManager,
      sessionPreviewManager: resolvedSessionPreviewManager,
      sessionMapBuilder: resolvedSessionMapBuilder,
      workspaceRelationshipMapBuilder: resolvedWorkspaceRelationshipMapBuilder
    )
    self.loadFeatureModel = WorkspaceLoadFeatureModel(
      operationRunner: operationRunner,
      fileEventSource: fileEventSource,
      clock: liveReloadClock
    )
    self.systemFeatureModel = WorkspaceSystemFeatureModel(
      workspacePicker: workspacePicker,
      workspaceInitializer: workspaceInitializer,
      fileRevealer: fileRevealer,
      installEnvironment: installEnvironment
    )
    self.installStatus = self.systemFeatureModel.refreshInstallStatus()
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
    self.recentWorkspacesFeatureModel = StudioRecentWorkspacesFeatureModel()
  }

}
