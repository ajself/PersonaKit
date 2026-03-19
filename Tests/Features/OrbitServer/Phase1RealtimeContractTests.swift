import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimeContractTests {
  @Test
  func realtimeCategoriesMatchThePacketThreeContract() {
    #expect(
      OrbitPhase1RealtimeContract.categories == [
        "post.created",
        "message.created",
        "thread.activity.updated",
        "participant.joined",
        "participant.failed",
        "activation.resolved",
        "activation.failed",
      ]
    )
  }

  @Test
  func replayCursorUsesLatestEventInCreationOrder() {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let earlierEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      workspaceID: workspaceID,
      category: .postCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400),
      payloadJSON: "{}"
    )
    let laterEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      workspaceID: workspaceID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_460),
      payloadJSON: "{}"
    )

    let cursor = OrbitPhase1RealtimeContract.makeReplayCursor(
      workspaceID: workspaceID,
      from: [laterEvent, earlierEvent]
    )

    #expect(cursor.workspaceID == workspaceID)
    #expect(cursor.lastEventID == laterEvent.id)
    #expect(cursor.lastEventCreatedAt == laterEvent.createdAt)
  }

  @Test
  func replayFiltersAndOrdersOnlyNewerEvents() {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)
    let t1 = Date(timeIntervalSince1970: 1_742_342_460)

    let oldEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "11111111-aaaa-aaaa-aaaa-111111111111")!,
      workspaceID: workspaceID,
      category: .postCreated,
      createdAt: t0,
      payloadJSON: "{}"
    )
    let cursorAnchor = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "22222222-bbbb-bbbb-bbbb-222222222222")!,
      workspaceID: workspaceID,
      category: .messageCreated,
      createdAt: t1,
      payloadJSON: "{}"
    )
    let newerSameTimestamp = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "33333333-cccc-cccc-cccc-333333333333")!,
      workspaceID: workspaceID,
      category: .threadActivityUpdated,
      createdAt: t1,
      payloadJSON: "{}"
    )
    let newest = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "44444444-dddd-dddd-dddd-444444444444")!,
      workspaceID: workspaceID,
      category: .activationResolved,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      payloadJSON: "{}"
    )

    let cursor = OrbitPhase1ReplayCursor(
      workspaceID: workspaceID,
      lastEventID: cursorAnchor.id,
      lastEventCreatedAt: cursorAnchor.createdAt
    )

    let replayEvents = OrbitPhase1RealtimeContract.events(
      since: cursor,
      in: [newest, oldEvent, newerSameTimestamp, cursorAnchor]
    )

    #expect(replayEvents == [newerSameTimestamp, newest])
  }
}
