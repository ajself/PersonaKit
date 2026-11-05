import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
  var recentWorkspaces: [StudioRecentWorkspace] {
    recentWorkspacesFeatureModel.workspaces
  }

  func configureRecentWorkspaces(
    storage: any StudioRecentWorkspacesPersisting,
    recentWorkspaceAccess: any StudioRecentWorkspaceAccessing,
    bookmarkDataProvider: @escaping (URL) -> Data? =
      StudioRecentWorkspacesState.securityScopedBookmarkData
  ) {
    recentWorkspacesFeatureModel = StudioRecentWorkspacesFeatureModel(
      storage: storage,
      recentWorkspaceAccess: recentWorkspaceAccess,
      bookmarkDataProvider: bookmarkDataProvider
    )
  }

  /// Loads a workspace passed through launch configuration. This is used by UI tests
  /// to exercise workspace-backed flows without going through the system open panel.
  public func loadLaunchWorkspaceIfNeeded(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) {
    guard workspaceURL == nil else {
      return
    }

    guard
      let launchWorkspaceURL = StudioLaunchConfiguration.launchWorkspaceURL(
        environment: environment,
        arguments: arguments
      )
    else {
      return
    }

    workspaceURL = launchWorkspaceURL
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

  func openWorkspacePickerAndRecordRecent() {
    StudioWorkspaceOpenCoordinator.openWorkspaceFromPicker(workspaceStore: self)
  }

  func openRecentWorkspace(_ workspace: StudioRecentWorkspace) {
    StudioWorkspaceOpenCoordinator.openRecentWorkspace(
      workspace,
      workspaceStore: self
    )
  }

  func removeRecentWorkspace(_ workspace: StudioRecentWorkspace) {
    recentWorkspacesFeatureModel.remove(workspace)
  }

  @discardableResult
  func recordRecentWorkspace(
    workspaceURL: URL,
    bookmarkData: Data? = nil
  ) -> Bool {
    recentWorkspacesFeatureModel.recordWorkspace(
      at: workspaceURL,
      bookmarkData: bookmarkData
    )
  }

  @discardableResult
  func recordCurrentWorkspaceIfLoaded() -> Bool {
    recentWorkspacesFeatureModel.recordCurrentWorkspaceIfLoaded(
      workspaceURL: workspaceURL
    )
  }

  func url(forRecentWorkspace workspace: StudioRecentWorkspace) -> URL {
    recentWorkspacesFeatureModel.url(for: workspace)
  }

  func stopRecentWorkspaceAccess() {
    recentWorkspacesFeatureModel.stopAccess()
  }

  func presentAgentSetup() {
    isAgentSetupPresented = true
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

  /// The global library root the snapshot, validator, and maps currently read, if any.
  var currentGlobalScopeURL: URL? {
    if let globalScopeProvider {
      return globalScopeProvider.current()
    }

    return WorkspaceScopeResolver.defaultGlobalScopeURL()
  }

  /// Reloads workspace data into the current snapshot and error state.
  func loadWorkspace() {
    loadWorkspace(trigger: .explicit)
  }

  /// Reloads the workspace. An explicit reload (open, save) resets in-flight work
  /// and shows validation progress; a reload for an external file change keeps everything
  /// on screen and lets each owner decide whether the changed files concern it.
  func loadWorkspace(trigger: WorkspaceReloadTrigger) {
    let trigger = inFlightReloadTrigger.map(trigger.merged(with:)) ?? trigger
    let changedFileURLs = trigger.changedFileURLs

    guard let workspaceURL else {
      inFlightReloadTrigger = nil
      libraryFeatureModel.invalidateRequests()
      loadFeatureModel.cancelLoadTask()
      loadFeatureModel.stopWatching()
      validationFeatureModel.cancelValidationTask()
      sessionFeatureModel.clearPreview()
      sessionFeatureModel.clearMap()
      sessionFeatureModel.clearDraftMap()
      snapshot = .empty
      loadErrorMessage = nil
      canInitializeWorkspaceStructure = false
      validation = .empty
      validationErrorMessage = nil
      libraryFeatureModel.resetState()
      return
    }

    loadFeatureModel.cancelLoadTask()
    inFlightReloadTrigger = trigger

    if changedFileURLs == nil {
      libraryFeatureModel.invalidateRequests()
      validationFeatureModel.cancelValidationTask()
      sessionFeatureModel.cancelPreviewTask()
      sessionFeatureModel.cancelMapTask()
      sessionFeatureModel.cancelDraftMapTask()
    }

    loadFeatureModel.loadWorkspace(
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onLoaded: { [workspaceURL] snapshot in
        self.inFlightReloadTrigger = nil
        self.snapshot = snapshot
        self.loadErrorMessage = nil
        self.canInitializeWorkspaceStructure = false

        if changedFileURLs == nil {
          self.validation = .empty
          self.validationErrorMessage = nil
        }

        self.sessionFeatureModel.revalidatePreviewAfterReload(
          snapshot: snapshot,
          workspaceURL: self.workspaceURL,
          changedFileURLs: changedFileURLs
        )
        self.sessionFeatureModel.revalidateMapAfterReload(
          snapshot: snapshot,
          workspaceURL: self.workspaceURL,
          changedFileURLs: changedFileURLs
        )
        self.libraryFeatureModel.revalidateDetailAfterReload(
          changedFileURLs: changedFileURLs
        )
        self.libraryFeatureModel.refreshUsageGraph(workspaceURL: workspaceURL)
        self.validationFeatureModel.runValidation(
          workspaceURL: workspaceURL,
          showsProgress: changedFileURLs == nil
        )
        self.watchLoadedWorkspace()
      },
      onMissingPersonaKitDirectory: { error in
        guard changedFileURLs == nil else {
          // Keep the failed batch pending so the reload that follows a fix still sees it.
          self.keepLastSnapshotAfterFailedExternalReload(workspaceURL: workspaceURL)
          return
        }

        self.inFlightReloadTrigger = nil

        self.loadFeatureModel.stopWatching()
        self.snapshot = .empty
        self.loadErrorMessage = error.localizedDescription
        self.canInitializeWorkspaceStructure = true
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.clearPreview()
        self.sessionFeatureModel.clearMap()
        self.sessionFeatureModel.clearDraftMap()
      },
      onLoadFailure: { message in
        guard changedFileURLs == nil else {
          // Keep the failed batch pending so the reload that follows a fix still sees it.
          self.keepLastSnapshotAfterFailedExternalReload(workspaceURL: workspaceURL)
          return
        }

        self.inFlightReloadTrigger = nil

        self.snapshot = .empty
        self.loadErrorMessage = message
        self.canInitializeWorkspaceStructure = false
        self.validation = .empty
        self.validationErrorMessage = nil
        self.sessionFeatureModel.clearPreview()
        self.sessionFeatureModel.clearMap()
        self.sessionFeatureModel.clearDraftMap()
        // Keep watching so fixing the broken file on disk reloads the workspace.
        self.watchLoadedWorkspace()
      }
    )
  }

  /// A file caught mid-write or briefly malformed fails the whole snapshot. Dropping to an
  /// empty snapshot would clear selections and discard unsaved inline edits, so an external
  /// reload that fails keeps the last good snapshot, keeps watching, and lets validation
  /// report the problem; the next change that fixes the file reloads normally.
  private func keepLastSnapshotAfterFailedExternalReload(workspaceURL: URL) {
    validationFeatureModel.runValidation(
      workspaceURL: workspaceURL,
      showsProgress: false
    )
  }

  /// Runs validator checks and refreshes diagnostics state.
  func validateWorkspace() {
    guard let workspaceURL else {
      validationFeatureModel.cancelValidationTask()
      validationFeatureModel.reset()
      return
    }

    validationFeatureModel.runValidation(workspaceURL: workspaceURL)
  }

  /// Validates and shows Validation Results, so a menu-driven run always has a visible result.
  func validateWorkspaceAndShowResults() {
    guard workspaceURL != nil else {
      return
    }

    validateWorkspace()
    pendingNavigationTarget = StudioNavigationTarget(sidebarItem: .validationResults, searchText: "")
  }

  func clearPendingNavigationTarget() {
    pendingNavigationTarget = nil
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
