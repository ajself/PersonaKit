import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitServerBackedRoomStateTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func bootstrapResponseProjectsCanonicalRoomIntoOrbitWorkspace() throws {
    let snapshot = sampleSnapshot()
    var state = OrbitServerBackedRoomState()

    try state.apply(
      .bootstrap(
        OrbitPhase1RealtimeSession(
          scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
          replayCursor: snapshot.replayCursor,
          connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
          lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
        snapshot
      )
    )

    #expect(state.projectedWorkspace?.displayName == "Orbit")
    #expect(state.projectedWorkspace?.activeThread?.messages.count == 1)
    #expect(state.projectedWorkspace?.participants.map(\.id).sorted() == ["aj", "samwise"])
  }

  @Test
  func replayResponseReducesSnapshotAndUpdatesProjectedWorkspace() throws {
    let snapshot = sampleSnapshot()
    let session = OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
    let messageID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let replayEvent = OrbitPhase1RealtimeEventEnvelope(
      id: messageID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_500),
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: messageID,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: "workspace-persona-orbit-samwise",
          body: "Server-backed replay response",
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_500),
          replyToMessageID: nil
        )
      )
    )
    let updatedSession = OrbitPhase1RealtimeSession(
      scope: session.scope,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: replayEvent.id,
        lastEventCreatedAt: replayEvent.createdAt
      ),
      connectedAt: session.connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_500)
    )
    var state = OrbitServerBackedRoomState(
      snapshot: snapshot,
      session: session,
      projectedWorkspace: OrbitServerRoomProjection.workspace(from: snapshot)
    )

    try state.apply(.replay(updatedSession, [replayEvent]))

    #expect(state.snapshot?.room.messages.count == 2)
    #expect(state.projectedWorkspace?.activeThread?.messages.last?.body == "Server-backed replay response")
    #expect(state.session?.replayCursor.lastEventID == replayEvent.id)
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
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
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        )
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
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }
}
