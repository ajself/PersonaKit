import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
  @Published var workspaceURL: URL?

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

    workspaceURL = selectedURL
  }
}
