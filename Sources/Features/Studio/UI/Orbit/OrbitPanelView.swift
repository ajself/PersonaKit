import OrbitServerRuntime
import SwiftUI

struct OrbitPanelView: View {
  let workspaceStore: WorkspaceStore
  let serverBackedRoomClient: OrbitServerBackedRoomClient?

  @SceneStorage(StudioHelpStorageKey.orbit)
  private var isOrbitHelpExpanded = false

  @State var orbitWorkspace = OrbitWorkspace.defaultWorkspace
  @State var draftMessageBody = ""
  @State var addressedParticipantID: String?
  @State var promoteToMeetingRoom = false
  @State var meetingSummaryDraft = ""
  @State var meetingOutcome = OrbitPhase1MeetingCompletionOutcome.decision
  @State var meetingDecisionTitleDraft = ""
  @State var meetingDecisionBodyDraft = ""
  @State var meetingNoDecisionDetailDraft = ""
  @State var meetingOpenQuestionsDraft = ""
  @State var meetingFollowUpReferencesDraft = ""
  @State var meetingCompletionDraftsDirty = false
  @State var syncedMeetingDraftPostID: String?
  @State var isSubmittingMeetingCompletion = false
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
      if isMeetingRoom {
        meetingOutputsCard
      }
      if showsStructuredNotesAndDecisionsCard {
        structuredNotesAndDecisionsCard
      }
      if showsStructuredReferencesAndArtifactsCard {
        structuredReferencesAndArtifactsCard
      }

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
      syncMeetingCompletionDrafts(force: true)
    }
    .task(id: workspaceStore.workspaceURL) {
      guard let serverBackedRoomClient else {
        return
      }

      await pollServerBackedOrbitRoomLoop(using: serverBackedRoomClient)
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      loadConfiguredOrbitRoom()
    }
    .onChange(of: addressedParticipantID) { _, _ in
      if !showsMeetingPromotionToggle {
        promoteToMeetingRoom = false
      }
    }
    .onChange(of: orbitWorkspace) { _, _ in
      if !showsMeetingPromotionToggle {
        promoteToMeetingRoom = false
      }

      syncMeetingCompletionDrafts()
    }
    .onChange(of: orbitWorkspace) { _, _ in
      if serverBackedRoomClient == nil {
        persistOrbitWorkspace()
      }
    }
  }
}
