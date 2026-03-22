import Foundation
import Synchronization
import Testing

@testable import OrbitServerRuntime

struct Phase1MeetingRoomCreationServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let samwiseID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let prodDocID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func createMeetingRoomBootstrapsMeetingRecordsAndReturnsTargetedScope() async throws {
    let recorder = MeetingBootstrapRecorder()
    let createdAt = Date(timeIntervalSince1970: 1_742_342_600)
    let postID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let threadID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let firstParticipantID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    let secondParticipantID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let noteID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    let participantIDs = Mutex<[UUID]>([
      firstParticipantID,
      secondParticipantID,
    ])
    let service = OrbitPhase1MeetingRoomCreationService(
      loadContext: { _, _ in sampleContext() },
      loadCreatedRoom: { _, _, _ in await recorder.snapshot },
      bootstrapRoom: { bootstrap in
        await recorder.record(bootstrap)
      },
      now: { createdAt },
      makePostID: { postID },
      makeThreadID: { threadID },
      makePostParticipantID: {
        participantIDs.withLock { ids in
          ids.removeFirst()
        }
      },
      makeNoteID: { noteID }
    )

    let result = try await service.createMeetingRoom(
      OrbitPhase1CreateMeetingRoomRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        title: "Founding Group Promotion",
        meetingType: .team,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        members: [
          OrbitPhase1MeetingMemberSpec(
            workspacePersonaID: prodDocID,
            participationRole: .contributor,
            selectedReason: "Selected from founding-group target."
          ),
          OrbitPhase1MeetingMemberSpec(
            workspacePersonaID: samwiseID,
            participationRole: .contributor,
            selectedReason: "Selected from founding-group target."
          ),
        ]
      )
    )

    let bootstrap = try #require(await recorder.bootstrap)
    #expect(bootstrap.post.id == postID)
    #expect(bootstrap.post.postType == .meeting)
    #expect(bootstrap.thread.id == threadID)
    #expect(bootstrap.seedMessages.isEmpty)
    #expect(bootstrap.meetingState?.status == .created)
    #expect(bootstrap.notes.count == 1)
    #expect(bootstrap.notes.first?.id == noteID)
    #expect(bootstrap.notes.first?.noteType == .meetingSummary)
    #expect(bootstrap.notes.first?.body == "Summary pending.")
    #expect(bootstrap.meetingOutputState?.outcomeState == .pending)
    #expect(bootstrap.meetingMembers.map(\.postParticipantID) == [firstParticipantID, secondParticipantID])
    #expect(bootstrap.postParticipants.map(\.participantID) == [samwiseID.uuidString, prodDocID.uuidString])
    #expect(result.scope.postID == postID)
    #expect(result.snapshot.post.id == postID)
    #expect(result.snapshot.notes == bootstrap.notes)
    #expect(result.snapshot.meetingOutputState == bootstrap.meetingOutputState)
    #expect(result.snapshot.meetingMembers.count == 2)
    #expect(result.snapshot.meetingState?.status == .created)
  }

  @Test
  func createMeetingRoomFailsWhenWorkspacePersonaIsMissing() async {
    let service = OrbitPhase1MeetingRoomCreationService(
      loadContext: { _, _ in sampleContext() },
      loadCreatedRoom: { _, _, _ in nil },
      bootstrapRoom: { _ in
        Issue.record("bootstrapRoom should not be called")
      }
    )

    do {
      _ = try await service.createMeetingRoom(
        OrbitPhase1CreateMeetingRoomRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          title: "Founding Group Promotion",
          meetingType: .team,
          startedByParticipantType: .user,
          startedByParticipantID: "aj",
          members: [
            OrbitPhase1MeetingMemberSpec(
              workspacePersonaID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
              participationRole: .contributor,
              selectedReason: "Selected from founding-group target."
            )
          ]
        )
      )
      Issue.record("Expected missing workspace persona error")
    } catch let error as OrbitPhase1MeetingRoomCreationServiceError {
      #expect(
        error
          == .workspacePersonaNotFound(
            UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
          )
      )
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleContext() -> OrbitPhase1MeetingRoomContext {
    OrbitPhase1MeetingRoomContext(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: samwiseID,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_401)
        ),
        OrbitWorkspacePersonaRecord(
          id: prodDocID,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_402)
        ),
      ]
    )
  }
}

private actor MeetingBootstrapRecorder {
  private(set) var bootstrap: OrbitPhase1RoomBootstrap?
  private(set) var snapshot: OrbitPhase1RoomSnapshot?

  func record(
    _ bootstrap: OrbitPhase1RoomBootstrap
  ) {
    self.bootstrap = bootstrap
    self.snapshot = OrbitPhase1RoomSnapshot(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      teams: bootstrap.teams,
      squads: bootstrap.squads,
      workspacePersonaMemberships: bootstrap.workspacePersonaMemberships,
      post: bootstrap.post,
      thread: bootstrap.thread,
      messages: bootstrap.seedMessages,
      postParticipants: bootstrap.postParticipants,
      notes: bootstrap.notes,
      decisions: bootstrap.decisions,
      references: bootstrap.references,
      meetingOutputState: bootstrap.meetingOutputState,
      meetingOpenQuestions: bootstrap.meetingOpenQuestions,
      meetingState: bootstrap.meetingState,
      meetingMembers: bootstrap.meetingMembers,
      postEvents: bootstrap.postEvents,
      personaActivations: bootstrap.personaActivations,
      agentRuns: bootstrap.agentRuns
    )
  }
}
