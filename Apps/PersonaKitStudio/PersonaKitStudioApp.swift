import SwiftUI

@main
struct PersonaKitStudioApp: App {
  @StateObject private var workspaceStore = WorkspaceStore()

  var body: some Scene {
    WindowGroup {
      StudioRootView(workspaceStore: workspaceStore)
    }
    .commands {
      CommandGroup(after: .newItem) {
        Button("Open Workspace…") {
          workspaceStore.openWorkspacePicker()
        }
        .keyboardShortcut("o", modifiers: [.command])
      }
    }
  }
}
