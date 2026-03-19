import SwiftUI

struct OrbitPanelView: View {
  let workspaceStore: WorkspaceStore
  let serverBackedRoomClient: OrbitServerBackedRoomClient?

  @SceneStorage(StudioHelpStorageKey.orbit)
  private var isOrbitHelpExpanded = false

  @State var orbitWorkspace = OrbitWorkspace.defaultWorkspace
  @State var draftMessageBody = ""
  @State var addressedParticipantID: String?
  @State var expandedTraceMessageIDs: Set<String>
  @State var serverBackedRoomCoordinator = OrbitServerBackedRoomCoordinator()
  @State var persistenceMessage: String?
  @State var persistenceIsError = false

  init(
    workspaceStore: WorkspaceStore,
    serverBackedRoomClient: OrbitServerBackedRoomClient? = nil,
    initialExpandedTraceMessageIDs: Set<String> = []
  ) {
    self.workspaceStore = workspaceStore
    self.serverBackedRoomClient = serverBackedRoomClient
    _expandedTraceMessageIDs = State(initialValue: initialExpandedTraceMessageIDs)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let helpTopic = StudioHelpCatalog.topic(for: SidebarItem.orbit) {
        StudioInlineHelpView(
          topic: helpTopic,
          isExpanded: $isOrbitHelpExpanded
        )
      }

      workspaceHeaderCard
      rosterCard

      if let persistenceMessage {
        Text(persistenceMessage)
          .font(.footnote)
          .foregroundStyle(persistenceIsError ? .red : .secondary)
          .padding(.horizontal, 16)
      }

      conversationCard
      composerCard
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      loadConfiguredOrbitRoom()
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      loadConfiguredOrbitRoom()
    }
    .onChange(of: orbitWorkspace) { _, _ in
      if serverBackedRoomClient == nil {
        persistOrbitWorkspace()
      }
    }
  }
}
