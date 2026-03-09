import ContextCore
import Foundation

extension WorkspaceStore {
  private static let launchWorkspacePathEnvironmentKey =
    "PERSONAKIT_STUDIO_INITIAL_WORKSPACE_PATH"

  /// Loads a workspace passed through the launch environment. This is used by UI tests
  /// to exercise workspace-backed flows without going through the system open panel.
  public func loadLaunchWorkspaceIfNeeded(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    guard workspaceURL == nil else {
      return
    }

    guard
      let rawPath = environment[Self.launchWorkspacePathEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawPath.isEmpty
    else {
      return
    }

    workspaceURL =
      URL(fileURLWithPath: rawPath, isDirectory: true)
      .standardizedFileURL
    loadWorkspace()
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
      sessionFeatureModel.clearMap()
      sessionFeatureModel.clearDraftMap()
      sessionFeatureModel.clearWorkspaceRelationshipMap()
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
    sessionFeatureModel.cancelMapTask()
    sessionFeatureModel.cancelDraftMapTask()
    sessionFeatureModel.cancelWorkspaceRelationshipMapTask()

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
        self.sessionFeatureModel.restoreMapIfPossible(
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
        self.sessionFeatureModel.clearMap()
        self.sessionFeatureModel.clearDraftMap()
        self.sessionFeatureModel.clearWorkspaceRelationshipMap()
      },
      onLoadFailure: { message in
        self.snapshot = .empty
        self.loadErrorMessage = message
        self.canInitializeWorkspaceStructure = false
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.clearPreview()
        self.sessionFeatureModel.clearMap()
        self.sessionFeatureModel.clearDraftMap()
        self.sessionFeatureModel.clearWorkspaceRelationshipMap()
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
