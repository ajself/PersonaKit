import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1MeetingRoomPromotionServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let originPostID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let originThreadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  private let createdPostID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
  private let createdThreadID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

  @Test
  func promoteMeetingRoomWritesOriginAttemptAndCreatesMeetingRoomTogether() async throws {
    let recorder = MeetingPromotionRecorder()
    let createdAt = Date(timeIntervalSince1970: 1_742_342_700)
    let preparedMeeting = samplePreparedMeeting()
    let service = OrbitPhase1MeetingRoomPromotionService(
      loadOriginSnapshot: { _, _, _ in sampleOriginSnapshot() },
      prepareMeetingRoom: { _ in preparedMeeting },
      bootstrapPromotedMeetingRoom: { originPostEvent, originRealtimeEvents, room in
        await recorder.record(
          originPostEvent: originPostEvent,
          originRealtimeEvents: originRealtimeEvents,
          room: room
        )
      },
      loadCreatedRoom: { _, _, _ in await recorder.snapshot },
      now: { createdAt },
      makePostEventID: { UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")! }
    )

    let result = try await service.promoteMeetingRoom(
      OrbitPhase1PromoteMeetingRoomRequest(
        originPostID: originPostID,
        meeting: OrbitPhase1CreateMeetingRoomRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          title: "Founding Group Meeting",
          meetingType: .team,
          startedByParticipantType: .user,
          startedByParticipantID: "aj",
          members: [
            OrbitPhase1MeetingMemberSpec(
              workspacePersonaID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
              participationRole: .contributor,
              selectedReason: "Selected from founding-group target."
            )
          ]
        ),
        promotion: OrbitPhase1MeetingPromotionEventPayload(
          initiatedByParticipantID: "aj",
          addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
          addressedTargetReferenceID: "founding-group",
          targetDisplayName: "Founding Group",
          meetingType: OrbitMeetingType.team.rawValue,
          title: "Founding Group Meeting",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          ]
        )
      )
    )

    let originPostEvent = try #require(await recorder.originPostEvent)
    let originRealtimeEvents = await recorder.originRealtimeEvents
    let bootstrappedRoom = try #require(await recorder.room)

    #expect(originPostEvent.postID == originPostID)
    #expect(originPostEvent.threadID == originThreadID)
    #expect(originPostEvent.eventType == OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue)
    #expect(originPostEvent.createdAt == createdAt)
    #expect(originRealtimeEvents.count == 1)
    #expect(originRealtimeEvents.first?.category == .meetingPromotionAttempted)
    #expect(bootstrappedRoom.post.id == createdPostID)
    #expect(result.originPostEvent == originPostEvent)
    #expect(result.meeting.scope.postID == createdPostID)
    #expect(result.meeting.snapshot.post.id == createdPostID)
  }

  @Test
  func promoteMeetingRoomFailsWhenOriginThreadIsMissing() async {
    let service = OrbitPhase1MeetingRoomPromotionService(
      loadOriginSnapshot: { _, _, _ in nil },
      prepareMeetingRoom: { _ in
        Issue.record("prepareMeetingRoom should not be called")
        return self.samplePreparedMeeting()
      },
      bootstrapPromotedMeetingRoom: { _, _, _ in
        Issue.record("bootstrapPromotedMeetingRoom should not be called")
      },
      loadCreatedRoom: { _, _, _ in nil }
    )

    do {
      _ = try await service.promoteMeetingRoom(
        OrbitPhase1PromoteMeetingRoomRequest(
          originPostID: originPostID,
          meeting: OrbitPhase1CreateMeetingRoomRequest(
            workspaceSlug: "orbit",
            channelSlug: "command-center",
            title: "Founding Group Meeting",
            meetingType: .team,
            startedByParticipantType: .user,
            startedByParticipantID: "aj",
            members: []
          ),
          promotion: OrbitPhase1MeetingPromotionEventPayload(
            initiatedByParticipantID: "aj",
            addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
            addressedTargetReferenceID: "founding-group",
            targetDisplayName: "Founding Group",
            meetingType: OrbitMeetingType.team.rawValue,
            title: "Founding Group Meeting",
            memberWorkspacePersonaIDs: []
          )
        )
      )
      Issue.record("Expected missing origin room failure")
    } catch let error as OrbitPhase1MeetingRoomPromotionServiceError {
      #expect(error == .originRoomNotFound)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleOriginSnapshot() -> OrbitPhase1RoomSnapshot {
    OrbitPhase1RoomSnapshot(
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
      post: OrbitPostRecord(
        id: originPostID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit checkpoint room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: originThreadID,
        postID: originPostID,
        status: .open,
        lastActivityAt: Date(timeIntervalSince1970: 1_742_342_400),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      messages: []
    )
  }

  private func samplePreparedMeeting() -> OrbitPhase1PreparedMeetingRoom {
    let workspace = sampleOriginSnapshot().workspace
    let channel = sampleOriginSnapshot().channel
    let participantID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let participantRecordID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let createdAt = Date(timeIntervalSince1970: 1_742_342_701)

    return OrbitPhase1PreparedMeetingRoom(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: createdPostID
      ),
      bootstrap: OrbitPhase1RoomBootstrap(
        workspace: workspace,
        channel: channel,
        workspacePersonas: [
          OrbitWorkspacePersonaRecord(
            id: participantID,
            workspaceID: workspaceID,
            personaTemplateID: "samwise",
            displayName: "Samwise",
            status: .active,
            createdAt: createdAt
          )
        ],
        post: OrbitPostRecord(
          id: createdPostID,
          workspaceID: workspaceID,
          channelID: channelID,
          postType: .meeting,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          title: "Founding Group Meeting",
          status: .active,
          createdAt: createdAt
        ),
        thread: OrbitThreadRecord(
          id: createdThreadID,
          postID: createdPostID,
          status: .open,
          lastActivityAt: createdAt,
          createdAt: createdAt
        ),
        seedMessages: [],
        postParticipants: [
          OrbitPostParticipantRecord(
            id: participantRecordID,
            postID: createdPostID,
            participantType: .workspacePersona,
            participantID: participantID.uuidString,
            joinedAt: createdAt,
            participationMode: .active
          )
        ],
        meetingState: OrbitMeetingStateRecord(
          postID: createdPostID,
          meetingType: .team,
          status: .created,
          startedByParticipantType: .user,
          startedByParticipantID: "aj",
          startedAt: createdAt
        ),
        meetingMembers: [
          OrbitMeetingMemberRecord(
            id: participantRecordID,
            meetingPostID: createdPostID,
            postParticipantID: participantRecordID,
            participationRole: .contributor,
            selectedReason: "Selected from founding-group target.",
            joinedAt: createdAt
          )
        ]
      )
    )
  }
}

private actor MeetingPromotionRecorder {
  private(set) var originPostEvent: OrbitPostEventRecord?
  private(set) var originRealtimeEvents = [OrbitRealtimeEventRecord]()
  private(set) var room: OrbitPhase1RoomBootstrap?
  private(set) var snapshot: OrbitPhase1RoomSnapshot?

  func record(
    originPostEvent: OrbitPostEventRecord,
    originRealtimeEvents: [OrbitRealtimeEventRecord],
    room: OrbitPhase1RoomBootstrap
  ) {
    self.originPostEvent = originPostEvent
    self.originRealtimeEvents = originRealtimeEvents
    self.room = room
    self.snapshot = OrbitPhase1RoomSnapshot(
      workspace: room.workspace,
      channel: room.channel,
      workspacePersonas: room.workspacePersonas,
      teams: room.teams,
      squads: room.squads,
      workspacePersonaMemberships: room.workspacePersonaMemberships,
      post: room.post,
      thread: room.thread,
      messages: room.seedMessages,
      postParticipants: room.postParticipants,
      meetingState: room.meetingState,
      meetingMembers: room.meetingMembers,
      postEvents: room.postEvents,
      personaActivations: room.personaActivations,
      agentRuns: room.agentRuns
    )
  }
}
