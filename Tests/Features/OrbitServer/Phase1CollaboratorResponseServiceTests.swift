import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1CollaboratorResponseServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  private let workspacePersonaID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
  private let triggerMessageID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

  @Test
  func appendCollaboratorResponseCreatesMessageActivationAndRun() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_520)
    let recorder = CollaboratorAppendRecorder()
    let service = OrbitPhase1CollaboratorResponseService(
      loadSnapshot: { _, _ in sampleSnapshot() },
      appendResponse: { workspaceID, message, activation, agentRun, postEvent, realtimeEvents, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          activation: activation,
          agentRun: agentRun,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents
        )
      },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "77777777-7777-7777-7777-777777777777")! },
      makeActivationID: { UUID(uuidString: "88888888-8888-8888-8888-888888888888")! },
      makeAgentRunID: { UUID(uuidString: "99999999-9999-9999-9999-999999999999")! },
      makePostEventID: { UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")! }
    )

    let result = try await service.appendCollaboratorResponse(
      OrbitPhase1AppendCollaboratorResponseRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        workspacePersonaID: workspacePersonaID,
        initiatedByParticipantID: "aj",
        triggerMessageID: triggerMessageID,
        addressedTargetKind: .collaborator,
        addressedTargetReferenceID: workspacePersonaID.uuidString,
        responseMode: .directAddress,
        body: "Canonical collaborator response",
        contract: OrbitPhase1ResolvedContractPayload(
          directiveID: "maintain-partner-sync-and-handoffs",
          directiveSource: "participantDefault",
          kitIDs: ["trusted-partner-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          reviewGateIDs: ["intent:partner-sync-review"]
        )
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.message?.body == "Canonical collaborator response")
    #expect(await recorder.activation?.resolvedWorkspacePersonaInstanceID == workspacePersonaID)
    #expect(await recorder.agentRun?.status == .completed)
    let postEvent = try #require(await recorder.postEvent)
    #expect(postEvent.eventType == OrbitPhase1RealtimeEventCategory.activationResolved.rawValue)
    let eventCategories = await recorder.realtimeEvents.map(\.category)
    #expect(eventCategories.count == 3)
    #expect(eventCategories.contains(.messageCreated))
    #expect(eventCategories.contains(.threadActivityUpdated))
    #expect(eventCategories.contains(.activationResolved))
    let activationEvent = try #require(
      await recorder.realtimeEvents.first(where: { $0.category == .activationResolved })
    )
    #expect(activationEvent.id == postEvent.id)
    #expect(activationEvent.payloadJSON == postEvent.payloadJSON)
    let payload = try #require(await recorder.postEventPayload)
    #expect(payload.contract?.directiveID == "maintain-partner-sync-and-handoffs")
    #expect(payload.contract?.kitIDs == ["trusted-partner-core"])
    #expect(payload.contract?.reviewGateIDs == ["intent:partner-sync-review"])
    #expect(result.snapshot.messages.count == 2)
    #expect(result.snapshot.personaActivations.count == 1)
    #expect(result.snapshot.agentRuns.count == 1)
  }

  @Test
  func appendCollaboratorResponseFailsWhenWorkspacePersonaIsMissing() async {
    let service = OrbitPhase1CollaboratorResponseService(
      loadSnapshot: { _, _ in sampleSnapshot(workspacePersonas: []) },
      appendResponse: { _, _, _, _, _, _, _ in
        Issue.record("appendResponse should not be called")
      }
    )

    do {
      _ = try await service.appendCollaboratorResponse(
        OrbitPhase1AppendCollaboratorResponseRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          workspacePersonaID: workspacePersonaID,
          initiatedByParticipantID: "aj",
          triggerMessageID: triggerMessageID,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          responseMode: .directAddress,
          body: "fail"
        )
      )
      Issue.record("Expected missing workspace persona error")
    } catch let error as OrbitPhase1CollaboratorResponseServiceError {
      #expect(error == .workspacePersonaNotFound)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func appendCollaboratorResponseFailsWhenTriggerMessageIsMissing() async {
    let service = OrbitPhase1CollaboratorResponseService(
      loadSnapshot: { _, _ in sampleSnapshot(messages: []) },
      appendResponse: { _, _, _, _, _, _, _ in
        Issue.record("appendResponse should not be called")
      }
    )

    do {
      _ = try await service.appendCollaboratorResponse(
        OrbitPhase1AppendCollaboratorResponseRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          workspacePersonaID: workspacePersonaID,
          initiatedByParticipantID: "aj",
          triggerMessageID: triggerMessageID,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          responseMode: .directAddress,
          body: "fail"
        )
      )
      Issue.record("Expected missing trigger message error")
    } catch let error as OrbitPhase1CollaboratorResponseServiceError {
      #expect(error == .triggerMessageNotFound)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleSnapshot(
    workspacePersonas: [OrbitWorkspacePersonaRecord]? = nil,
    messages: [OrbitMessageRecord]? = nil
  ) -> OrbitPhase1RoomSnapshot {
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
      workspacePersonas: workspacePersonas ?? [
        OrbitWorkspacePersonaRecord(
          id: workspacePersonaID,
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
      messages: messages ?? [
        OrbitMessageRecord(
          id: triggerMessageID,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Trigger message",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ]
    )
  }
}

private actor CollaboratorAppendRecorder {
  var workspaceID: UUID?
  var message: OrbitMessageRecord?
  var activation: OrbitPersonaActivationRecord?
  var agentRun: OrbitAgentRunRecord?
  var postEvent: OrbitPostEventRecord?
  var realtimeEvents = [OrbitRealtimeEventRecord]()
  var postEventPayload: OrbitPhase1ActivationEventPayload?

  func record(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord]
  ) {
    self.workspaceID = workspaceID
    self.message = message
    self.activation = activation
    self.agentRun = agentRun
    self.postEvent = postEvent
    self.realtimeEvents = realtimeEvents
    self.postEventPayload = try? OrbitPhase1RealtimeEventPayloadCodec.decode(
      OrbitPhase1ActivationEventPayload.self,
      from: postEvent.payloadJSON
    )
  }
}
