import ContextCore
import ContextWorkspaceCore
import Foundation

extension WorkspaceStore {
  var recentWorkspaces: [StudioRecentWorkspace] {
    _ = recentWorkspacesRevision

    return recentWorkspacesFeatureModel.workspaces
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
    recentWorkspacesRevision &+= 1
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
    guard recentWorkspacesFeatureModel.remove(workspace) else {
      return
    }

    recentWorkspacesRevision &+= 1
  }

  @discardableResult
  func recordRecentWorkspace(
    workspaceURL: URL,
    bookmarkData: Data? = nil
  ) -> Bool {
    guard
      recentWorkspacesFeatureModel.recordWorkspace(
        at: workspaceURL,
        bookmarkData: bookmarkData
      )
    else {
      return false
    }

    recentWorkspacesRevision &+= 1
    return true
  }

  @discardableResult
  func recordCurrentWorkspaceIfLoaded() -> Bool {
    guard
      recentWorkspacesFeatureModel.recordCurrentWorkspaceIfLoaded(
        workspaceURL: workspaceURL
      )
    else {
      return false
    }

    recentWorkspacesRevision &+= 1
    return true
  }

  func url(forRecentWorkspace workspace: StudioRecentWorkspace) -> URL {
    recentWorkspacesFeatureModel.url(for: workspace)
  }

  func stopRecentWorkspaceAccess() {
    recentWorkspacesFeatureModel.stopAccess()
  }

  func refreshInstallStatus() {
    installStatus = systemFeatureModel.refreshInstallStatus()
  }

  func installOrUpdateCLI() {
    installResult = systemFeatureModel.installOrUpdateCLI()
    refreshInstallStatus()
  }

  func installOrUpdateOpenCodeMCP() {
    installResult = systemFeatureModel.installOrUpdateOpenCodeMCP()
    refreshInstallStatus()
  }

  func dismissInstallResult() {
    installResult = nil
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

  /// `true` when the global PersonaKit library is currently readable — either through a
  /// user grant applied to this store's provider, or (in unsandboxed builds) the live
  /// `~/.personakit` default. While `false`, unresolved shared-entity references can't be
  /// verified, so Studio surfaces the Connect prompt instead of per-reference errors.
  var isGlobalLibraryConnected: Bool {
    if let globalScopeProvider {
      return globalScopeProvider.current() != nil
    }

    return WorkspaceScopeResolver.defaultGlobalScopeURL() != nil
  }

  /// Presents the global-library folder picker, persists the grant for future launches,
  /// applies it to the live provider, and revalidates the open workspace. A picked folder
  /// without a `Packs/` directory is accepted but flagged with a non-blocking warning —
  /// connecting a wrong or empty root leaves any genuine breakage visible as real errors.
  func connectGlobalLibrary() {
    globalLibraryConnectWarning = nil

    guard let pickedURL = globalLibraryPicker.pickGlobalLibraryURL() else {
      return
    }

    let grantedURL = pickedURL.standardizedFileURL
    globalLibraryAccess?.persist(grantedURL: grantedURL)

    if !WorkspaceScopeResolver.directoryExists(PersonaKitDirectory.packsURL(root: grantedURL)) {
      globalLibraryConnectWarning =
        "The selected folder has no Packs directory, so it may not be a PersonaKit library."
    }

    setGlobalScope(grantedURL)
  }

  /// Applies a user-granted global library scope (or clears it with `nil`) and reloads
  /// the open workspace so snapshot, validation, and maps re-resolve against it.
  ///
  /// No-op when this store was not launch-configured with a late-bindable provider.
  public func setGlobalScope(_ url: URL?) {
    guard let globalScopeProvider else {
      return
    }

    globalScopeProvider.setURL(url)
    loadWorkspace()
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
