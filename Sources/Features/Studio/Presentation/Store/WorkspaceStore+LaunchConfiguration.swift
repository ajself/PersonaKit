import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
  public static func launchConfigured(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> WorkspaceStore {
    launchConfigured(
      environment: environment,
      globalLibraryAccess: StudioGlobalLibraryAccess(
        userDefaults: StudioLaunchConfiguration.userDefaults(environment: environment)
      )
    )
  }

  /// Launch precedence for the initial global scope: environment override →
  /// persisted bookmark grant → none (fall back to the live default).
  static func launchConfigured(
    environment: [String: String],
    globalLibraryAccess: StudioGlobalLibraryAccess
  ) -> WorkspaceStore {
    let initialURL =
      StudioLaunchConfiguration.globalScopeURL(environment: environment)
      ?? globalLibraryAccess.resolveGrantedURL()
    let provider = WorkspaceGlobalScopeProvider(
      initialURL: initialURL,
      fallback: { WorkspaceScopeResolver.defaultGlobalScopeURL(fileManager: .default) }
    )

    return WorkspaceStore(
      globalScopeProvider: provider,
      globalLibraryAccess: globalLibraryAccess
    )
  }

  /// Builds a store whose snapshot/validation/preview/maps read the global library
  /// through a late-bindable provider, so a post-launch grant can be applied via
  /// ``setGlobalScope(_:)`` without rebuilding the store.
  public convenience init(globalScopeProvider: WorkspaceGlobalScopeProvider) {
    let scope: @Sendable () -> URL? = { globalScopeProvider.current() }
    let sessionManager = WorkspaceSessionManager()
    let livePreviewDependencies = WorkspaceSessionPreviewManagerDependencies.live()
    let previewDependencies = WorkspaceSessionPreviewManagerDependencies(
      directoryExists: livePreviewDependencies.directoryExists,
      fileExists: livePreviewDependencies.fileExists,
      defaultGlobalScopeURL: scope,
      createDirectory: livePreviewDependencies.createDirectory,
      writeData: livePreviewDependencies.writeData
    )

    self.init(
      snapshotBuilder: WorkspaceSnapshotBuilder(globalScopeProvider: scope),
      workspaceValidator: WorkspaceValidator(globalScopeProvider: scope),
      sessionManager: sessionManager,
      sessionPreviewManager: WorkspaceSessionPreviewManager(
        sessionManager: sessionManager,
        dependencies: previewDependencies
      ),
      sessionMapBuilder: WorkspaceSessionMapBuilder(globalScopeProvider: scope),
      workspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilder(
        globalScopeProvider: scope
      ),
      globalScopeProvider: globalScopeProvider
    )
  }
}
