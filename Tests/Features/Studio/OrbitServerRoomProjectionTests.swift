import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitServerRoomProjectionTests {
  @Test
  func projectionBuildsBelievableOrbitWorkspaceFromCanonicalSnapshot() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)

    #expect(workspace.id == "orbit")
    #expect(workspace.displayName == "Orbit")
    #expect(workspace.purpose == "Primary Orbit room")
    #expect(workspace.participants.map(\.id).sorted() == ["aj", "proddoc", "samwise"])
    #expect(workspace.activeThread?.title == "Orbit room")
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
    #expect(workspace.activeThread?.messages.count == 3)
  }

  @Test
  func projectionPreservesSpeakerMeaningAcrossCanonicalAuthors() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)
    let messages = workspace.activeThread?.messages ?? []

    #expect(messages[0].speakerParticipantID == OrbitParticipantID.aj.rawValue)
    #expect(messages[0].kind == .user)
    #expect(messages[1].speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(messages[1].kind == .participantResponse)
    #expect(messages[2].speakerParticipantID == OrbitParticipantID.prodDoc.rawValue)
    #expect(messages[2].kind == .participantResponse)
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)

    let room = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: t0
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: t0
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: t0
        ),
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: t0.addingTimeInterval(1)
        ),
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .meeting,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: t0
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: t0.addingTimeInterval(60),
        createdAt: t0
      ),
      messages: [
        OrbitMessageRecord(
          id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Founding group, regroup.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: t0.addingTimeInterval(10),
          updatedAt: t0.addingTimeInterval(10)
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-samwise",
          body: "Samwise is here.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: t0.addingTimeInterval(20),
          updatedAt: t0.addingTimeInterval(20)
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-proddoc",
          body: "ProdDoc is here.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: t0.addingTimeInterval(30),
          updatedAt: t0.addingTimeInterval(30)
        ),
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: t0.addingTimeInterval(5),
          participationMode: .active
        ),
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-proddoc",
          joinedAt: t0.addingTimeInterval(6),
          participationMode: .active
        ),
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!,
        lastEventCreatedAt: t0.addingTimeInterval(60)
      )
    )
  }
}
