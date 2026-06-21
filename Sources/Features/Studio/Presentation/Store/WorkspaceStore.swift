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

        libraryFeatureModel.resetState()
        sessionFeatureModel.clearPreview()
        sessionFeatureModel.clearMap()
        sessionFeatureModel.clearDraftMap()
        sessionFeatureModel.clearWorkspaceRelationshipMap()
        return
      }

      let standardizedWorkspaceURL = workspaceURL.standardizedFileURL

      if standardizedWorkspaceURL != workspaceURL {
        self.workspaceURL = standardizedWorkspaceURL
      }

      guard standardizedOldWorkspaceURL != standardizedWorkspaceURL else {
        return
      }

      libraryFeatureModel.resetState()
    }
  }
  var snapshot: WorkspaceSnapshot = .empty {
    didSet {
      guard snapshot != oldValue else {
        return
      }

      snapshotRevision &+= 1
    }
  }
  private(set) var snapshotRevision = 0
  // Keeps @Observable views subscribed when async validation mutates nested feature state.
  private var validationRevision = 0
  // Keeps @Observable views subscribed when the recent-workspace owner persists changes.
  var recentWorkspacesRevision = 0
  var loadErrorMessage: String?
  var canInitializeWorkspaceStructure = false
  var installStatus: WorkspaceInstallStatus
  var installResult: StudioInstallResult?
  var validation: WorkspaceValidationSnapshot {
    get {
      _ = validationRevision
      return validationFeatureModel.validation
    }

    set {
      validationFeatureModel.validation = newValue
    }
  }

  var validationErrorMessage: String? {
    get {
      _ = validationRevision
      return validationFeatureModel.validationErrorMessage
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
  var workspaceRelationshipMap: WorkspaceSessionMap? {
    sessionFeatureModel.workspaceRelationshipMap
  }

  var workspaceRelationshipMapErrorMessage: String? {
    sessionFeatureModel.workspaceRelationshipMapErrorMessage
  }

  var isLoadingWorkspaceRelationshipMap: Bool {
    sessionFeatureModel.isLoadingWorkspaceRelationshipMap
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

  public init(
    snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder(),
    workspaceValidator: any WorkspaceValidating = WorkspaceValidator(),
    sessionManager: any WorkspaceSessionManaging = WorkspaceSessionManager(),
    essentialManager: (any WorkspaceEssentialManaging)? = nil,
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
    self.globalScopeProvider = globalScopeProvider
    self.globalLibraryAccess = globalLibraryAccess
    self.globalLibraryPicker = globalLibraryPicker

    let resolvedEssentialManager =
      essentialManager
      ?? WorkspaceEssentialManager()

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
      essentialManager: resolvedEssentialManager,
      libraryEntityManager: resolvedLibraryEntityManager,
      sessionPreviewManager: resolvedSessionPreviewManager,
      sessionMapBuilder: resolvedSessionMapBuilder,
      workspaceRelationshipMapBuilder: resolvedWorkspaceRelationshipMapBuilder
    )
    self.loadFeatureModel = WorkspaceLoadFeatureModel(operationRunner: operationRunner)
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
    self.validationFeatureModel.onChange = { [weak self] in
      self?.validationRevision &+= 1
    }
  }

}
