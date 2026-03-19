import Foundation
import Testing

@testable import OrbitServerRuntime

struct OrbitPostgresRealtimeLoaderTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func loaderBuildsDeterministicallyOrderedEventsFromRoomSnapshot() {
    let events = sampleRealtimeEvents()

    #expect(events.map(\.category) == [
      .postCreated,
      .participantJoined,
      .messageCreated,
      .messageCreated,
      .threadActivityUpdated,
      .activationResolved,
    ])
    #expect(events.last?.id == UUID(uuidString: "77777777-7777-7777-7777-777777777777")!)
  }

  @Test
  func loaderFeedServiceBootstrapAndReplayUseSharedProjectionRules() async throws {
    let snapshot = sampleRealtimeSnapshot()
    let events = sampleRealtimeEvents()
    let latestCursor = OrbitPhase1RealtimeContract.makeReplayCursor(
      workspaceID: workspaceID,
      from: events
    )

    let feedService = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in snapshot },
      loadReplayBatch: { _, cursor in
        let replayEvents = OrbitPhase1RealtimeContract.events(since: cursor, in: events)
        return OrbitPhase1RealtimeReplayBatch(events: replayEvents)
      }
    )

    let bootstrappedSnapshot = try await feedService.bootstrap(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center")
    )
    let replayResult = try await feedService.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      cursor: latestCursor
    )

    #expect(bootstrappedSnapshot == snapshot)
    #expect(replayResult == .noChange(cursor: latestCursor))
  }

  private func sampleRoomSnapshot() -> OrbitPhase1RoomSnapshot {
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
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: Date(timeIntervalSince1970: 1_742_342_460),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      messages: [
        OrbitMessageRecord(
          id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-samwise",
          body: "Canonical replay should preserve this room.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: Date(timeIntervalSince1970: 1_742_342_420),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_420)
        ),
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ],
      postEvents: [
        OrbitPostEventRecord(
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          postID: postID,
          threadID: threadID,
          eventType: "activation.resolved",
          payloadJSON: "{\"response_mode\":\"direct-address\"}",
          createdAt: Date(timeIntervalSince1970: 1_742_342_470)
        )
      ],
      personaActivations: [],
      agentRuns: []
    )
  }

  private func sampleRealtimeSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let room = sampleRoomSnapshot()
    let events = sampleRealtimeEvents()

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1RealtimeContract.makeReplayCursor(
        workspaceID: workspaceID,
        from: events
      )
    )
  }

  private func sampleRealtimeEvents() -> [OrbitPhase1RealtimeEventEnvelope] {
    [
      OrbitPhase1RealtimeEventEnvelope(
        id: postID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .postCreated,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400),
        payloadJSON: "{\"post_id\":\"\(postID.uuidString)\"}"
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .participantJoined,
        createdAt: Date(timeIntervalSince1970: 1_742_342_405),
        payloadJSON: "{\"participant_id\":\"workspace-persona-orbit-samwise\",\"mode\":\"active\"}"
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .messageCreated,
        createdAt: Date(timeIntervalSince1970: 1_742_342_410),
        payloadJSON: "{\"message_id\":\"55555555-5555-5555-5555-555555555555\",\"author_id\":\"aj\"}"
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .messageCreated,
        createdAt: Date(timeIntervalSince1970: 1_742_342_420),
        payloadJSON: "{\"message_id\":\"66666666-6666-6666-6666-666666666666\",\"author_id\":\"workspace-persona-orbit-samwise\"}"
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: threadID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .threadActivityUpdated,
        createdAt: Date(timeIntervalSince1970: 1_742_342_460),
        payloadJSON: "{\"thread_id\":\"\(threadID.uuidString)\"}"
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .activationResolved,
        createdAt: Date(timeIntervalSince1970: 1_742_342_470),
        payloadJSON: "{\"response_mode\":\"direct-address\"}"
      ),
    ]
  }
}
