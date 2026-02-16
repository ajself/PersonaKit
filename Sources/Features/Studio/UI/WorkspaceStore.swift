import ContextCore
import Foundation
import Observation
import StudioFoundation

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
public final class WorkspaceStore {
  var workspaceURL: URL? {
    didSet {
      guard let workspaceURL else {
        return
      }

      let standardizedWorkspaceURL = workspaceURL.standardizedFileURL

      guard standardizedWorkspaceURL != workspaceURL else {
        return
      }

      self.workspaceURL = standardizedWorkspaceURL
    }
  }
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

  let loadFeatureModel: WorkspaceLoadFeatureModel
  let systemFeatureModel: WorkspaceSystemFeatureModel
  let libraryFeatureModel: WorkspaceLibraryFeatureModel
  let sessionEditorFeatureModel: WorkspaceSessionEditorFeatureModel
  let sessionFeatureModel: WorkspaceSessionFeatureModel
  let validationFeatureModel: WorkspaceValidationFeatureModel

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

}
