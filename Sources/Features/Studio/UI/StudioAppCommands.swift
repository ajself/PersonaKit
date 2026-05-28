import SwiftUI

public struct StudioAppCommands: Commands {
  let workspaceStore: WorkspaceStore

  public init(workspaceStore: WorkspaceStore) {
    self.workspaceStore = workspaceStore
  }

  public var body: some Commands {
    InspectorCommands()

    CommandGroup(after: .newItem) {
      Button("Open Workspace…") {
        workspaceStore.openWorkspacePickerAndRecordRecent()
      }
      .keyboardShortcut("o", modifiers: [.command])
    }

    CommandMenu("Install") {
      Button("Install or Update CLI…") {
        workspaceStore.installOrUpdateCLI()
      }

      Button("Install or Update MCP for OpenCode…") {
        workspaceStore.installOrUpdateOpenCodeMCP()
      }
    }
  }
}
