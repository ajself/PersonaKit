import SwiftUI

public struct StudioAppCommands: Commands {
  let workspaceStore: WorkspaceStore
  @FocusedValue(\.studioWindowActions) private var focusedWindow

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

      Button("Validate Workspace") {
        workspaceStore.validateWorkspaceAndShowResults(in: focusedWindow)
      }
      .disabled(workspaceStore.workspaceURL == nil)
    }

    CommandGroup(after: .appInfo) {
      Button("Set Up Agents…") {
        workspaceStore.presentAgentSetup(in: focusedWindow)
      }
    }
  }
}
