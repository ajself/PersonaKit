import AppKit
import Foundation
import Observation
import PersonaKitCore

/// Main-actor workspace state owner for Studio view rendering.
@Observable
@MainActor
final class WorkspaceStore {
  var workspaceURL: URL?
  var snapshot: WorkspaceSnapshot = .empty
  var loadErrorMessage: String?

  private let snapshotBuilder: any WorkspaceSnapshotBuilding

  init(snapshotBuilder: any WorkspaceSnapshotBuilding = WorkspaceSnapshotBuilder()) {
    self.snapshotBuilder = snapshotBuilder
  }

  /// Presents the folder picker and loads the selected workspace snapshot.
  func openWorkspacePicker() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    panel.message = "Choose a folder to use as the PersonaKit workspace."
    panel.prompt = "Open Workspace"

    guard panel.runModal() == .OK,
      let selectedURL = panel.url
    else {
      return
    }

    workspaceURL = selectedURL.standardizedFileURL
    loadWorkspace()
  }

  /// Reloads workspace data into the current snapshot and error state.
  func loadWorkspace() {
    guard let workspaceURL else {
      snapshot = .empty
      loadErrorMessage = nil
      return
    }

    do {
      snapshot = try snapshotBuilder.build(workspaceURL: workspaceURL)
      loadErrorMessage = nil
    } catch let error as WorkspaceSnapshotBuildError {
      snapshot = .empty
      loadErrorMessage = error.message
    } catch {
      snapshot = .empty
      loadErrorMessage = error.localizedDescription
    }
  }
}
