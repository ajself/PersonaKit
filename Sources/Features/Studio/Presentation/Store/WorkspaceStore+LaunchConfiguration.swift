import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
  public static func launchConfigured(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> WorkspaceStore {
    guard
      let globalScopeURL = StudioLaunchConfiguration.globalScopeURL(
        environment: environment
      )
    else {
      return WorkspaceStore()
    }

    return WorkspaceStore(globalScopeURL: globalScopeURL)
  }

  public convenience init(globalScopeURL: URL) {
    let sessionManager = WorkspaceSessionManager()
    let livePreviewDependencies = WorkspaceSessionPreviewManagerDependencies.live()
    let previewDependencies = WorkspaceSessionPreviewManagerDependencies(
      directoryExists: livePreviewDependencies.directoryExists,
      defaultGlobalScopeURL: { globalScopeURL },
      createDirectory: livePreviewDependencies.createDirectory,
      writeData: livePreviewDependencies.writeData
    )

    self.init(
      snapshotBuilder: WorkspaceSnapshotBuilder(globalScopeURL: globalScopeURL),
      workspaceValidator: WorkspaceValidator(globalScopeURL: globalScopeURL),
      sessionManager: sessionManager,
      sessionPreviewManager: WorkspaceSessionPreviewManager(
        sessionManager: sessionManager,
        dependencies: previewDependencies
      ),
      sessionMapBuilder: WorkspaceSessionMapBuilder(globalScopeURL: globalScopeURL),
      workspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilder(
        globalScopeURL: globalScopeURL
      )
    )
  }
}
