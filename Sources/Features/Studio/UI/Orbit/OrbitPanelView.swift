import SwiftUI

struct OrbitPanelView: View {
  let workspaceStore: WorkspaceStore

  @SceneStorage(StudioHelpStorageKey.orbit)
  private var isOrbitHelpExpanded = false

  @State var orbitWorkspace = OrbitWorkspace.defaultWorkspace
  @State var draftMessageBody = ""
  @State var addressedParticipantID = OrbitParticipantID.samwise.rawValue
  @State var persistenceMessage: String?
  @State var persistenceIsError = false

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
      loadOrbitWorkspace()
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      loadOrbitWorkspace()
    }
    .onChange(of: orbitWorkspace) { _, _ in
      persistOrbitWorkspace()
    }
  }
}
