import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
  public static func launchConfigured(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> WorkspaceStore {
    launchConfigured(
      environment: environment,
      fileEventSource: FSEventsWorkspaceFileEventStream()
    )
  }

  /// Launch precedence for the global scope: environment override → `~/.personakit` in
  /// the user's real home, when it exists → none (project-only).
  static func launchConfigured(
    environment: [String: String],
    fileEventSource: (any WorkspaceFileEventStreaming)?
  ) -> WorkspaceStore {
    let provider = WorkspaceGlobalScopeProvider(
      initialURL: StudioLaunchConfiguration.globalScopeURL(environment: environment),
      fallback: { WorkspaceGlobalScopeProvider.userHomeGlobalScopeURL() }
    )

    // Route through the provider-wiring init so the builders/validator read the box.
    return WorkspaceStore(
      globalScopeProvider: provider,
      fileEventSource: fileEventSource
    )
  }

  /// Builds a store whose snapshot/validation/preview/maps read the global library
  /// through the supplied provider.
  public convenience init(globalScopeProvider: WorkspaceGlobalScopeProvider) {
    self.init(globalScopeProvider: globalScopeProvider, fileEventSource: nil)
  }

  convenience init(
    globalScopeProvider: WorkspaceGlobalScopeProvider,
    fileEventSource: (any WorkspaceFileEventStreaming)?
  ) {
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
      globalScopeProvider: globalScopeProvider,
      fileEventSource: fileEventSource,
      liveReloadClock: ContinuousClock()
    )
  }
}
