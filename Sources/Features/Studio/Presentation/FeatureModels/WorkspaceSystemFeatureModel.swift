import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

/// Feature-owned system interaction model used by `WorkspaceStore`.
@MainActor
final class WorkspaceSystemFeatureModel {
  private let workspacePicker: any WorkspacePicking
  private let workspaceInitializer: WorkspaceInitializer
  private let fileRevealer: any FileRevealing
  private let installEnvironment: any WorkspaceInstallEnvironmentProviding

  init(
    workspacePicker: any WorkspacePicking,
    workspaceInitializer: WorkspaceInitializer,
    fileRevealer: any FileRevealing,
    installEnvironment: any WorkspaceInstallEnvironmentProviding =
      WorkspaceInstallEnvironmentClient()
  ) {
    self.workspacePicker = workspacePicker
    self.workspaceInitializer = workspaceInitializer
    self.fileRevealer = fileRevealer
    self.installEnvironment = installEnvironment
  }

  /// Presents the workspace picker and returns the selected folder URL.
  func pickWorkspaceURL() -> URL? {
    workspacePicker.pickWorkspaceURL()?.standardizedFileURL
  }

  /// Creates a minimal PersonaKit folder structure and returns whether initialization ran.
  func initializeWorkspaceStructure(at workspaceURL: URL?) throws -> Bool {
    guard let workspaceURL else {
      return false
    }

    try workspaceInitializer.initialize(
      at: workspaceURL.standardizedFileURL
    )

    return true
  }

  /// Reveals a file URL in Finder.
  func revealInFinder(fileURL: URL) {
    fileRevealer.reveal(fileURL.standardizedFileURL)
  }

  /// Resolves and reveals a diagnostics file path in Finder when possible.
  func revealValidationIssueInFinder(
    filePath: String,
    workspaceURL: URL?,
    snapshot: WorkspaceSnapshot
  ) {
    guard
      let fileURL = WorkspaceSnapshotLookup.resolveValidationIssueFileURL(
        filePath,
        workspaceURL: workspaceURL,
        snapshot: snapshot
      )
    else {
      return
    }

    fileRevealer.reveal(fileURL)
  }

  func installEnvironmentStatus() -> any WorkspaceInstallEnvironmentProviding {
    installEnvironment
  }
}
