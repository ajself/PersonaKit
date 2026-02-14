import SwiftUI

/// Entry point for the PersonaKit Studio macOS app.
@main
struct PersonaKitStudioApp: App {
  @State private var workspaceStore = WorkspaceStore()

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
