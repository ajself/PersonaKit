import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimeTransportAdapterTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

  @Test
  func connectReturnsBootstrapTransportResponse() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let adapter = OrbitPhase1RealtimeTransportAdapter(
      pollingService: OrbitPhase1RealtimePollingSessionService(
        adapter: OrbitPhase1RealtimeSubscriptionAdapter(
          feedService: OrbitPhase1RealtimeFeedService(
            loadSnapshot: { _ in snapshot },
            loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
          )
        ),
        staleAfter: 30,
        now: { Date(timeIntervalSince1970: 1_742_342_400) }
      )
    )

    let response = try await adapter.connect(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center")
      )
    )

    switch response {
    case .bootstrap(let session, let returnedSnapshot):
      #expect(returnedSnapshot == snapshot)
      #expect(session.replayCursor == snapshot.replayCursor)
    default:
      Issue.record("Expected bootstrap transport response")
    }
  }

  @Test
  func pollReturnsReplayTransportResponse() async throws {
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
      workspaceID: workspaceID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      payloadJSON: "{}"
    )
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!)
    let session = OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_410)
    )
    let adapter = OrbitPhase1RealtimeTransportAdapter(
      pollingService: OrbitPhase1RealtimePollingSessionService(
        adapter: OrbitPhase1RealtimeSubscriptionAdapter(
          feedService: OrbitPhase1RealtimeFeedService(
            loadSnapshot: { _ in snapshot },
            loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [event]) }
          )
        ),
        staleAfter: 30,
        now: { Date(timeIntervalSince1970: 1_742_342_420) }
      )
    )

    let response = try await adapter.poll(request: OrbitPhase1RealtimePollRequest(session: session))

    switch response {
    case .replay(let updatedSession, let events):
      #expect(events == [event])
      #expect(updatedSession.replayCursor.lastEventID == event.id)
    default:
      Issue.record("Expected replay transport response")
    }
  }

  @Test
  func pollReturnsResyncTransportResponseForStaleSession() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!)
    let session = OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
    let adapter = OrbitPhase1RealtimeTransportAdapter(
      pollingService: OrbitPhase1RealtimePollingSessionService(
        adapter: OrbitPhase1RealtimeSubscriptionAdapter(
          feedService: OrbitPhase1RealtimeFeedService(
            loadSnapshot: { _ in snapshot },
            loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
          )
        ),
        staleAfter: 30,
        now: { Date(timeIntervalSince1970: 1_742_342_500) }
      )
    )

    let response = try await adapter.poll(request: OrbitPhase1RealtimePollRequest(session: session))

    switch response {
    case .resync(let updatedSession, let returnedSnapshot, let reason):
      #expect(reason == .staleClient)
      #expect(returnedSnapshot == snapshot)
      #expect(updatedSession.replayCursor == snapshot.replayCursor)
    default:
      Issue.record("Expected resync transport response")
    }
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
