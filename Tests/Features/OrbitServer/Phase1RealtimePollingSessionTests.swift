import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimePollingSessionTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

  @Test
  func connectCreatesSessionFromBootstrapSnapshot() async throws {
    let scope = OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let service = OrbitPhase1RealtimePollingSessionService(
      adapter: OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: OrbitPhase1RealtimeFeedService(
          loadSnapshot: { _ in snapshot },
          loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
        )
      ),
      staleAfter: 30,
      now: { t0 }
    )

    let result = try await service.connect(
      handshake: OrbitPhase1SubscriptionHandshake(scope: scope)
    )

    #expect(result.delivery == .bootstrap(snapshot))
    #expect(result.session.scope == scope)
    #expect(result.session.connectedAt == t0)
    #expect(result.session.lastInteractionAt == t0)
    #expect(result.session.replayCursor == snapshot.replayCursor)
  }

  @Test
  func pollReturnsReplayAndAdvancesCursor() async throws {
    let scope = OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)
    let t1 = Date(timeIntervalSince1970: 1_742_342_420)
    let anchorID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let replayEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
      workspaceID: workspaceID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_460),
      payloadJSON: "{}"
    )
    let snapshot = sampleSnapshot(cursorEventID: anchorID)
    let connectService = OrbitPhase1RealtimePollingSessionService(
      adapter: OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: OrbitPhase1RealtimeFeedService(
          loadSnapshot: { _ in snapshot },
          loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [replayEvent]) }
        )
      ),
      staleAfter: 30,
      now: { t0 }
    )
    let pollService = OrbitPhase1RealtimePollingSessionService(
      adapter: OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: OrbitPhase1RealtimeFeedService(
          loadSnapshot: { _ in snapshot },
          loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [replayEvent]) }
        )
      ),
      staleAfter: 30,
      now: { t1 }
    )

    let initial = try await connectService.connect(
      handshake: OrbitPhase1SubscriptionHandshake(scope: scope)
    )
    let result = try await pollService.poll(session: initial.session)

    switch result.delivery {
    case .replay(let events, let nextCursor):
      #expect(events == [replayEvent])
      #expect(nextCursor.lastEventID == replayEvent.id)
      #expect(result.session.replayCursor == nextCursor)
      #expect(result.session.lastInteractionAt == t1)
    default:
      Issue.record("Expected replay delivery")
    }
  }

  @Test
  func pollReturnsNoChangeAndRefreshesInteractionTime() async throws {
    let scope = OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)
    let t1 = Date(timeIntervalSince1970: 1_742_342_410)
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!)
    let service = OrbitPhase1RealtimePollingSessionService(
      adapter: OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: OrbitPhase1RealtimeFeedService(
          loadSnapshot: { _ in snapshot },
          loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
        )
      ),
      staleAfter: 30,
      now: { t0 }
    )
    let initial = try await service.connect(
      handshake: OrbitPhase1SubscriptionHandshake(scope: scope)
    )
    let pollingService = OrbitPhase1RealtimePollingSessionService(
      adapter: service.adapter,
      staleAfter: 30,
      now: { t1 }
    )

    let result = try await pollingService.poll(session: initial.session)

    #expect(result.delivery == .noChange(snapshot.replayCursor))
    #expect(result.session.replayCursor == snapshot.replayCursor)
    #expect(result.session.lastInteractionAt == t1)
  }

  @Test
  func staleSessionResyncsFromSnapshot() async throws {
    let scope = OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)
    let t1 = Date(timeIntervalSince1970: 1_742_342_500)
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!)
    let service = OrbitPhase1RealtimePollingSessionService(
      adapter: OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: OrbitPhase1RealtimeFeedService(
          loadSnapshot: { _ in snapshot },
          loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
        )
      ),
      staleAfter: 30,
      now: { t0 }
    )
    let initial = try await service.connect(
      handshake: OrbitPhase1SubscriptionHandshake(scope: scope)
    )
    let staleService = OrbitPhase1RealtimePollingSessionService(
      adapter: service.adapter,
      staleAfter: 30,
      now: { t1 }
    )

    #expect(staleService.requiresResync(session: initial.session) == true)

    let result = try await staleService.poll(session: initial.session)

    #expect(result.delivery == .resync(snapshot, reason: .staleClient))
    #expect(result.session.replayCursor == snapshot.replayCursor)
    #expect(result.session.lastInteractionAt == t1)
  }

  private func sampleSnapshot(
    cursorEventID: UUID
  ) -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      channel: OrbitChannelRecord(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      post: OrbitPostRecord(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        workspaceID: workspaceID,
        channelID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        status: .open,
        lastActivityAt: Date(timeIntervalSince1970: 1_742_342_460),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      messages: []
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: cursorEventID,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }
}
