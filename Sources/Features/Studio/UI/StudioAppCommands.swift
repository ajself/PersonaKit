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

    CommandGroup(after: .appInfo) {
      Button("Set Up Agents…") {
        workspaceStore.presentAgentSetup()
      }
    }
  }
}
