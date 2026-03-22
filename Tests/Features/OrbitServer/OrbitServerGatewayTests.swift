import Foundation
import Testing
import Vapor
import WebSocketKit
import XCTVapor

@testable import OrbitServerGateway
@testable import OrbitServerRuntime

@Suite(.serialized)
struct OrbitServerGatewayTests {
  @Test
  func transportResponseEncodingPreservesLegacySummaryFields() throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let payload = OrbitGatewayTransportResponse(
      response: .bootstrap(
        OrbitPhase1RealtimeSession(
          scope: OrbitPhase1RealtimeSubscriptionScope(
            workspaceSlug: "orbit",
            channelSlug: "command-center"
          ),
          replayCursor: snapshot.replayCursor,
          connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
          lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
        snapshot
      )
    )
    let encoded = try JSONEncoder().encode(payload)
    let json = try #require(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    #expect(json["kind"] as? String == "bootstrap")
    #expect(json["session"] as? [String: Any] != nil)
    #expect(json["snapshot"] as? [String: Any] != nil)
    #expect(json["response"] as? [String: Any] != nil)
  }

  @Test
  func appendMessageResponseEncodingPreservesLegacySummaryFields() throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID())
    let message = OrbitMessageRecord(
      id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
      postID: snapshot.room.post.id,
      threadID: snapshot.room.thread.id,
      authorType: .user,
      authorID: "aj",
      body: "Canonical write path",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_500),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
    )
    let result = OrbitPhase1AppendUserMessageResult(
      snapshot: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: snapshot.room.messages + [message],
        postParticipants: snapshot.room.postParticipants,
        postEvents: snapshot.room.postEvents,
        personaActivations: snapshot.room.personaActivations,
        agentRuns: snapshot.room.agentRuns
      ),
      message: message
    )
    let encoded = try JSONEncoder().encode(
      OrbitGatewayAppendMessageResponse(result: result)
    )
    let json = try #require(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    #expect(json["workspaceSlug"] as? String == "orbit")
    #expect(json["messageCount"] as? Int == 1)
    #expect(json["result"] as? [String: Any] != nil)
  }

  @Test
  func connectRouteReturnsBootstrapPayload() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let app = try await Application.make(.testing)

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { request in
            #expect(
              request.scope.postID
                == UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
            )
            return .bootstrap(
              OrbitPhase1RealtimeSession(
                scope: OrbitPhase1RealtimeSubscriptionScope(
                  workspaceSlug: "orbit",
                  channelSlug: "command-center",
                  postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
                ),
                replayCursor: snapshot.replayCursor,
                connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
                lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
              ),
              snapshot
            )
          },
          pollHandler: { _ in
            Issue.record("Poll should not be called")
            return .noChange(snapshot.replayCursorSession)
          }
        )
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/realtime/connect",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayConnectRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
            #expect(payload.kind == "bootstrap")
            #expect(payload.snapshot?.workspaceSlug == "orbit")
            #expect(payload.snapshot?.messageCount == 0)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func appendMessageRouteReturnsCanonicalWritePayload() async throws {
    let app = try await Application.make(.testing)

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        roomWriter: StubRoomWriter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.authorID == "aj")
          #expect(request.body == "Canonical write path")

          let snapshot = sampleSnapshot(cursorEventID: UUID())
          let message = OrbitMessageRecord(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            authorType: .user,
            authorID: request.authorID,
            body: request.body,
            messageFormat: .plainText,
            state: .persisted,
            createdAt: Date(timeIntervalSince1970: 1_742_342_500),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
          let updatedSnapshot = OrbitPhase1RoomSnapshot(
            workspace: snapshot.room.workspace,
            channel: snapshot.room.channel,
            post: snapshot.room.post,
            thread: snapshot.room.thread,
            messages: snapshot.room.messages + [message]
          )

          return OrbitPhase1AppendUserMessageResult(
            snapshot: updatedSnapshot,
            message: message
          )
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/messages",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayAppendMessageRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                authorID: "aj",
                body: "Canonical write path"
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayAppendMessageResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.channelSlug == "command-center")
            #expect(payload.messageCount == 1)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func appendSystemMessageRouteReturnsCanonicalSystemMessagePayload() async throws {
    let app = try await Application.make(.testing)
    let replyToMessageID = UUID(uuidString: "17171717-1717-1717-1717-171717171717")!

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        systemWriter: StubSystemWriter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.body == "AJ invited Samwise and ProdDoc into the active lightweight meeting.")
          #expect(request.replyToMessageID == replyToMessageID)

          let snapshot = sampleSnapshot(cursorEventID: UUID())
          let message = OrbitMessageRecord(
            id: UUID(uuidString: "18181818-1818-1818-1818-181818181818")!,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            authorType: .system,
            authorID: "orbit-system",
            replyToMessageID: request.replyToMessageID,
            body: request.body,
            messageFormat: .plainText,
            state: .completed,
            createdAt: Date(timeIntervalSince1970: 1_742_342_501),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_501)
          )
          let updatedSnapshot = OrbitPhase1RoomSnapshot(
            workspace: snapshot.room.workspace,
            channel: snapshot.room.channel,
            post: snapshot.room.post,
            thread: snapshot.room.thread,
            messages: snapshot.room.messages + [message]
          )

          return OrbitPhase1AppendSystemMessageResult(
            snapshot: updatedSnapshot,
            message: message
          )
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/system-messages",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayAppendSystemMessageRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                body: "AJ invited Samwise and ProdDoc into the active lightweight meeting.",
                replyToMessageID: replyToMessageID
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayAppendSystemMessageResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.channelSlug == "command-center")
            #expect(payload.messageID == UUID(uuidString: "18181818-1818-1818-1818-181818181818"))
            #expect(payload.messageCount == 1)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func appendCollaboratorResponseRouteReturnsCanonicalResponsePayload() async throws {
    let app = try await Application.make(.testing)
    let activationID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let agentRunID = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        collaboratorWriter: StubCollaboratorWriter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.body == "Canonical collaborator response")
          #expect(request.contract?.authorizedSkillIDs == ["codex-cli"])
          #expect(request.contract?.reviewGateIDs == ["intent:partner-sync-review"])

          let snapshot = sampleSnapshot(cursorEventID: UUID())
          let message = OrbitMessageRecord(
            id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            authorType: .workspacePersona,
            authorID: request.workspacePersonaID.uuidString,
            replyToMessageID: request.triggerMessageID,
            body: request.body,
            messageFormat: .markdown,
            state: .completed,
            createdAt: Date(timeIntervalSince1970: 1_742_342_500),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
          let activation = OrbitPersonaActivationRecord(
            id: activationID,
            initiatedByParticipantType: .user,
            initiatedByParticipantID: request.initiatedByParticipantID,
            workspaceID: snapshot.room.workspace.id,
            channelID: snapshot.room.channel.id,
            originPostID: snapshot.room.post.id,
            originThreadID: snapshot.room.thread.id,
            triggerMessageID: request.triggerMessageID,
            addressedTargetKind: request.addressedTargetKind,
            addressedTargetReferenceID: request.addressedTargetReferenceID,
            resolvedWorkspacePersonaInstanceID: request.workspacePersonaID,
            responseMode: request.responseMode,
            createdAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
          let agentRun = OrbitAgentRunRecord(
            id: agentRunID,
            personaActivationID: activation.id,
            runnerKind: request.runnerKind,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 1_742_342_500),
            completedAt: Date(timeIntervalSince1970: 1_742_342_500)
          )

          return OrbitPhase1AppendCollaboratorResponseResult(
            snapshot: snapshot.room,
            message: message,
            activation: activation,
            agentRun: agentRun
          )
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/responses",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayAppendCollaboratorResponseRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                workspacePersonaID: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
                initiatedByParticipantID: "aj",
                triggerMessageID: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
                addressedTargetKind: OrbitAddressedTargetKind.collaborator.rawValue,
                addressedTargetReferenceID: "workspace-persona-orbit-samwise",
                responseMode: OrbitCanonicalResponseMode.directAddress.rawValue,
                body: "Canonical collaborator response",
                contract: OrbitPhase1ResolvedContractPayload(
                  directiveID: "maintain-partner-sync-and-handoffs",
                  directiveSource: "participantDefault",
                  kitIDs: ["trusted-partner-core"],
                  authorizedSkillIDs: ["codex-cli"],
                  requiredSkillIDs: ["codex-cli"],
                  stopPointIDs: [],
                  reviewGateIDs: ["intent:partner-sync-review"],
                  memoryScopeIDs: []
                )
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayAppendCollaboratorResponse.self)
            #expect(payload.activationID == activationID)
            #expect(payload.agentRunID == agentRunID)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func appendActivationFailureRouteReturnsCanonicalFailurePayload() async throws {
    let app = try await Application.make(.testing)
    let triggerMessageID = UUID(uuidString: "19191919-1919-1919-1919-191919191919")!
    let systemMessageID = UUID(uuidString: "20202020-2020-2020-2020-202020202020")!
    let postEventID = UUID(uuidString: "21212121-2121-2121-2121-212121212121")!

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        failureWriter: StubFailureWriter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.initiatedByParticipantID == "aj")
          #expect(request.triggerMessageID == triggerMessageID)
          #expect(request.failure.failureReason == "missingDirective")
          #expect(request.failure.systemEventMessageID == systemMessageID)

          let snapshot = sampleSnapshot(cursorEventID: UUID())
          let triggerMessage = OrbitMessageRecord(
            id: triggerMessageID,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            authorType: .user,
            authorID: "aj",
            body: "ProdDoc, pressure-test the checkpoint.",
            messageFormat: .plainText,
            state: .persisted,
            createdAt: Date(timeIntervalSince1970: 1_742_342_500),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
          let systemMessage = OrbitMessageRecord(
            id: systemMessageID,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            authorType: .system,
            authorID: "orbit-system",
            replyToMessageID: triggerMessageID,
            body: request.failure.systemEventBody,
            messageFormat: .plainText,
            state: .completed,
            createdAt: Date(timeIntervalSince1970: 1_742_342_501),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_501)
          )
          let postEvent = OrbitPostEventRecord(
            id: postEventID,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
            payloadJSON: "{}",
            createdAt: Date(timeIntervalSince1970: 1_742_342_501)
          )
          let updatedSnapshot = OrbitPhase1RoomSnapshot(
            workspace: snapshot.room.workspace,
            channel: snapshot.room.channel,
            post: snapshot.room.post,
            thread: snapshot.room.thread,
            messages: [triggerMessage, systemMessage],
            postEvents: [postEvent]
          )

          return OrbitPhase1AppendActivationFailureResult(
            snapshot: updatedSnapshot,
            systemMessage: systemMessage,
            postEvent: postEvent
          )
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/activation-failures",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayAppendActivationFailureRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                initiatedByParticipantID: "aj",
                triggerMessageID: triggerMessageID,
                failure: OrbitPhase1ActivationFailurePayload(
                  addressedTargetID: "prod-doc",
                  participantID: "prod-doc",
                  workspacePersonaID: UUID(uuidString: "22222222-2222-2222-2222-222222222220")!.uuidString,
                  personaTemplateID: "venture-product-steward",
                  directiveID: nil,
                  triggerSource: "directAddress",
                  systemEventMessageID: systemMessageID,
                  requiredSkillIDs: ["codex-cli"],
                  authorizedSkillIDs: ["codex-cli"],
                  failureReason: "missingDirective",
                  systemEventBody:
                    "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint."
                )
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayAppendActivationFailureResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.channelSlug == "command-center")
            #expect(payload.systemMessageID == systemMessageID)
            #expect(payload.postEventID == postEventID)
            #expect(payload.messageCount == 2)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func appendMeetingPromotionEventRouteReturnsCanonicalPromotionPayload() async throws {
    let app = try await Application.make(.testing)
    let postEventID = UUID(uuidString: "31313131-3131-3131-3131-313131313131")!

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        promotionWriter: StubMeetingPromotionWriter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.promotion.addressedTargetReferenceID == "founding-group")
          #expect(request.promotion.failure == nil)

          let snapshot = sampleSnapshot(cursorEventID: UUID())
          let postEvent = OrbitPostEventRecord(
            id: postEventID,
            postID: snapshot.room.post.id,
            threadID: snapshot.room.thread.id,
            eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
            payloadJSON: "{}",
            createdAt: Date(timeIntervalSince1970: 1_742_342_520)
          )
          let updatedSnapshot = OrbitPhase1RoomSnapshot(
            workspace: snapshot.room.workspace,
            channel: snapshot.room.channel,
            post: snapshot.room.post,
            thread: snapshot.room.thread,
            messages: snapshot.room.messages,
            postEvents: [postEvent]
          )

          return OrbitPhase1AppendMeetingPromotionEventResult(
            snapshot: updatedSnapshot,
            postEvent: postEvent
          )
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/meeting-promotions",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayAppendMeetingPromotionEventRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                promotion: OrbitPhase1MeetingPromotionEventPayload(
                  initiatedByParticipantID: "aj",
                  addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
                  addressedTargetReferenceID: "founding-group",
                  targetDisplayName: "Founding Group",
                  meetingType: OrbitMeetingType.team.rawValue,
                  title: "Founding Group Meeting",
                  memberWorkspacePersonaIDs: [
                    UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
                  ]
                )
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayAppendMeetingPromotionEventResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.channelSlug == "command-center")
            #expect(payload.postEventID == postEventID)
            #expect(payload.systemMessageID == nil)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func pollRouteReturnsReplayPayload() async throws {
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
      workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      payloadJSON: "{}"
    )
    let app = try await Application.make(.testing)

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in
            Issue.record("Connect should not be called")
            return .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession)
          },
          pollHandler: { request in
            .replay(request.session.updatedSession(with: event), [event])
          }
        )
      )

      let session = OrbitGatewaySessionPayload(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        cursorEventID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        cursorEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_400),
        connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
        lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_410)
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/realtime/poll",
          beforeRequest: { request in
            try request.content.encode(OrbitGatewayPollRequest(session: session))
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
            #expect(payload.kind == "replay")
            #expect(payload.events.count == 1)
            #expect(payload.events.first?.category == "message.created")
            #expect(payload.session.cursorEventID == event.id)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func pollRouteReturnsResyncPayload() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!)
    let app = try await Application.make(.testing)

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in
            Issue.record("Connect should not be called")
            return .noChange(snapshot.replayCursorSession)
          },
          pollHandler: { request in
            .resync(request.session.updatedSession(with: snapshot.replayCursor), snapshot, .staleClient)
          }
        )
      )

      let session = OrbitGatewaySessionPayload(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        cursorEventID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        cursorEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_400),
        connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
        lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_410)
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/realtime/poll",
          beforeRequest: { request in
            try request.content.encode(OrbitGatewayPollRequest(session: session))
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
            #expect(payload.kind == "resync")
            #expect(payload.resyncReason == "stale-client")
            #expect(payload.snapshot?.workspaceSlug == "orbit")
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func socketRouteReturnsBootstrapPayload() async throws {
    let snapshot = sampleSnapshot(
      cursorEventID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    )
    let app = try await Application.make(.testing)

    do {
      app.http.server.configuration.port = 0
      app.environment.arguments = ["serve"]

      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { request in
            #expect(request.scope.workspaceSlug == "orbit")
            #expect(request.scope.channelSlug == "command-center")

            return .bootstrap(
              OrbitPhase1RealtimeSession(
                scope: request.scope,
                replayCursor: snapshot.replayCursor,
                connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
                lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
              ),
              snapshot
            )
          },
          pollHandler: { _ in
            Issue.record("Poll should not be called")
            return .noChange(snapshot.replayCursorSession)
          }
        )
      )

      try await app.startup()

      let port = try #require(app.http.server.shared.localAddress?.port)
      let responsePromise = app.eventLoopGroup.next().makePromise(
        of: OrbitGatewayTransportResponse.self
      )

      try await WebSocket.connect(
        to: "ws://127.0.0.1:\(port)/api/orbit/realtime/socket?workspaceSlug=orbit&channelSlug=command-center",
        on: app.eventLoopGroup
      ) { socket in
        socket.onText { socket, text in
          do {
            let payload = try JSONDecoder().decode(
              OrbitGatewayTransportResponse.self,
              from: Data(text.utf8)
            )
            responsePromise.succeed(payload)
          } catch {
            responsePromise.fail(error)
          }

          try? await socket.close()
        }

        try? await socket.send("{\"kind\":\"bootstrap\"}")
      }

      let payload = try await responsePromise.futureResult.get()
      #expect(payload.kind == "bootstrap")
      #expect(payload.snapshot?.workspaceSlug == "orbit")
      #expect(payload.snapshot?.messageCount == 0)
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func createMeetingRoomRouteReturnsCanonicalMeetingPayload() async throws {
    let app = try await Application.make(.testing)
    let result = OrbitPhase1CreateMeetingRoomResult(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
      ),
      snapshot: sampleSnapshot(cursorEventID: UUID()).room
    )

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        meetingCreator: StubMeetingCreator { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.title == "Founding Group Promotion")
          #expect(request.meetingType == .team)
          #expect(request.members.count == 1)
          return result
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/meetings",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayCreateMeetingRoomRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                title: "Founding Group Promotion",
                meetingType: OrbitMeetingType.team.rawValue,
                startedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
                startedByParticipantID: "aj",
                members: [
                  OrbitPhase1MeetingMemberSpec(
                    workspacePersonaID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    participationRole: .contributor,
                    selectedReason: "Selected from founding-group target."
                  )
                ]
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayCreateMeetingRoomResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.postID == result.snapshot.post.id)
            #expect(payload.memberCount == 0)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func promoteMeetingRoomRouteReturnsCanonicalPromotionPayload() async throws {
    let app = try await Application.make(.testing)
    let result = OrbitPhase1PromoteMeetingRoomResult(
      meeting: OrbitPhase1CreateMeetingRoomResult(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        ),
        snapshot: sampleSnapshot(cursorEventID: UUID()).room
      ),
      originPostEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
        postID: sampleSnapshot(cursorEventID: UUID()).room.post.id,
        threadID: sampleSnapshot(cursorEventID: UUID()).room.thread.id,
        eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_521)
      )
    )

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        meetingPromoter: StubMeetingPromoter { request in
          #expect(request.originPostID == sampleSnapshot(cursorEventID: UUID()).room.post.id)
          #expect(request.meeting.workspaceSlug == "orbit")
          #expect(request.meeting.channelSlug == "command-center")
          #expect(request.meeting.title == "Founding Group Promotion")
          #expect(request.promotion.addressedTargetReferenceID == "founding-group")
          return result
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/promoted-meetings",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayPromoteMeetingRoomRequest(
                originPostID: sampleSnapshot(cursorEventID: UUID()).room.post.id,
                meeting: OrbitGatewayCreateMeetingRoomRequest(
                  workspaceSlug: "orbit",
                  channelSlug: "command-center",
                  title: "Founding Group Promotion",
                  meetingType: OrbitMeetingType.team.rawValue,
                  startedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
                  startedByParticipantID: "aj",
                  members: [
                    OrbitPhase1MeetingMemberSpec(
                      workspacePersonaID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
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
                  title: "Founding Group Promotion",
                  memberWorkspacePersonaIDs: [
                    UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
                  ]
                )
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayPromoteMeetingRoomResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.originPostEventID == result.originPostEvent.id)
            #expect(payload.postID == result.meeting.snapshot.post.id)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  @Test
  func completeMeetingRouteReturnsCanonicalMeetingOutputPayload() async throws {
    let app = try await Application.make(.testing)
    let snapshot = sampleMeetingSnapshot(
      cursorEventID: UUID(uuidString: "35353535-3535-3535-3535-353535353535")!,
      status: .completed,
      outcomeState: .decisionRecorded,
      summaryBody: "Completed summary"
    )
    let summaryNote = try #require(snapshot.room.notes.first)
    let meetingOutputState = try #require(snapshot.room.meetingOutputState)
    let postEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "36363636-3636-3636-3636-363636363636")!,
      postID: snapshot.room.post.id,
      threadID: snapshot.room.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.meetingOutputCommitted.rawValue,
      payloadJSON: "{}",
      createdAt: Date(timeIntervalSince1970: 1_742_342_540)
    )
    let result = OrbitPhase1CompleteMeetingResult(
      snapshot: snapshot.room,
      summaryNote: summaryNote,
      meetingOutputState: meetingOutputState,
      decision: snapshot.room.decisions.first,
      references: snapshot.room.references,
      meetingOpenQuestions: snapshot.room.meetingOpenQuestions,
      postEvent: postEvent
    )

    do {
      OrbitGatewayRoutes.register(
        on: app,
        transport: StubTransport(
          connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
          pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
        ),
        meetingCompleter: StubMeetingCompleter { request in
          #expect(request.workspaceSlug == "orbit")
          #expect(request.channelSlug == "command-center")
          #expect(request.postID == snapshot.room.post.id)
          #expect(request.summaryBody == "Completed summary")
          #expect(request.outcome == .decision)
          #expect(request.decisionTitle == "Ship packet 4")
          #expect(request.decisionBody == "Keep meeting outputs inspectable after reload.")
          #expect(request.openQuestions == ["How should edits work?"])
          #expect(request.followUpReferences.first?.referenceType == .doc)
          #expect(request.completedByParticipantType == .user)
          #expect(request.completedByParticipantID == "aj")
          return result
        }
      )

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(
          .POST,
          "/api/orbit/room/meeting-completions",
          beforeRequest: { request in
            try request.content.encode(
              OrbitGatewayCompleteMeetingRequest(
                workspaceSlug: "orbit",
                channelSlug: "command-center",
                postID: snapshot.room.post.id,
                summaryBody: "Completed summary",
                outcome: OrbitPhase1MeetingCompletionOutcome.decision.rawValue,
                decisionTitle: "Ship packet 4",
                decisionBody: "Keep meeting outputs inspectable after reload.",
                openQuestions: ["How should edits work?"],
                followUpReferences: [
                  OrbitGatewayMeetingReferencePayload(
                    referenceType: OrbitReferenceType.doc.rawValue,
                    target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
                    title: "Packet scope"
                  )
                ],
                completedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
                completedByParticipantID: "aj"
              )
            )
          },
          afterResponse: { response in
            #expect(response.status == .ok)
            let payload = try response.content.decode(OrbitGatewayCompleteMeetingResponse.self)
            #expect(payload.workspaceSlug == "orbit")
            #expect(payload.postID == snapshot.room.post.id)
            #expect(payload.postEventID == postEvent.id)
            #expect(payload.outcomeState == OrbitMeetingOutcomeState.decisionRecorded.rawValue)
            #expect(payload.decisionID == snapshot.room.decisions.first?.id)
            #expect(payload.openQuestionCount == 1)
            #expect(payload.referenceCount == 1)
          }
        )
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }
}

private struct StubTransport: OrbitRealtimeTransportHandling {
  let connectHandler: @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimePollRequest) async throws -> OrbitPhase1RealtimeTransportResponse

  func connect(request: OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await connectHandler(request)
  }

  func poll(request: OrbitPhase1RealtimePollRequest) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await pollHandler(request)
  }
}

private struct StubRoomWriter: OrbitPhase1RoomWriteServing {
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult

  init(
    _ appendHandler:
      @escaping @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    try await appendHandler(request)
  }
}

private struct StubCollaboratorWriter: OrbitCollaboratorResponseHandling {
  let appendHandler:
    @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult

  init(
    _ appendHandler:
      @escaping @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws ->
      OrbitPhase1AppendCollaboratorResponseResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    try await appendHandler(request)
  }
}

private struct StubSystemWriter: OrbitSystemMessageHandling {
  let appendHandler:
    @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult

  init(
    _ appendHandler:
      @escaping @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendSystemMessage(
    _ request: OrbitPhase1AppendSystemMessageRequest
  ) async throws -> OrbitPhase1AppendSystemMessageResult {
    try await appendHandler(request)
  }
}

private struct StubFailureWriter: OrbitActivationFailureHandling {
  let appendHandler:
    @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult

  init(
    _ appendHandler:
      @escaping @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws ->
      OrbitPhase1AppendActivationFailureResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult {
    try await appendHandler(request)
  }
}

private struct StubMeetingPromotionWriter: OrbitMeetingPromotionEventHandling {
  let appendHandler:
    @Sendable (OrbitPhase1AppendMeetingPromotionEventRequest) async throws ->
      OrbitPhase1AppendMeetingPromotionEventResult

  init(
    _ appendHandler:
      @escaping @Sendable (OrbitPhase1AppendMeetingPromotionEventRequest) async throws ->
      OrbitPhase1AppendMeetingPromotionEventResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendMeetingPromotionEvent(
    _ request: OrbitPhase1AppendMeetingPromotionEventRequest
  ) async throws -> OrbitPhase1AppendMeetingPromotionEventResult {
    try await appendHandler(request)
  }
}

private struct StubMeetingCreator: OrbitMeetingRoomCreationHandling {
  let createHandler: @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult

  init(
    _ createHandler:
      @escaping @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult
  ) {
    self.createHandler = createHandler
  }

  func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult {
    try await createHandler(request)
  }
}

private struct StubMeetingPromoter: OrbitMeetingRoomPromotionHandling {
  let promoteHandler:
    @Sendable (OrbitPhase1PromoteMeetingRoomRequest) async throws -> OrbitPhase1PromoteMeetingRoomResult

  init(
    _ promoteHandler:
      @escaping @Sendable (OrbitPhase1PromoteMeetingRoomRequest) async throws -> OrbitPhase1PromoteMeetingRoomResult
  ) {
    self.promoteHandler = promoteHandler
  }

  func promoteMeetingRoom(
    _ request: OrbitPhase1PromoteMeetingRoomRequest
  ) async throws -> OrbitPhase1PromoteMeetingRoomResult {
    try await promoteHandler(request)
  }
}

private struct StubMeetingCompleter: OrbitMeetingCompletionHandling {
  let completionHandler: @Sendable (OrbitPhase1CompleteMeetingRequest) async throws -> OrbitPhase1CompleteMeetingResult

  init(
    _ completionHandler:
      @escaping @Sendable (OrbitPhase1CompleteMeetingRequest) async throws -> OrbitPhase1CompleteMeetingResult
  ) {
    self.completionHandler = completionHandler
  }

  func completeMeeting(
    _ request: OrbitPhase1CompleteMeetingRequest
  ) async throws -> OrbitPhase1CompleteMeetingResult {
    try await completionHandler(request)
  }
}

extension OrbitPhase1RealtimeSnapshot {
  fileprivate var replayCursorSession: OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: room.workspace.slug, channelSlug: room.channel.slug),
      replayCursor: replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
  }
}

extension OrbitPhase1RealtimeSession {
  fileprivate func updatedSession(
    with event: OrbitPhase1RealtimeEventEnvelope
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: scope,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: replayCursor.workspaceID,
        lastEventID: event.id,
        lastEventCreatedAt: event.createdAt
      ),
      connectedAt: connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_420)
    )
  }

  fileprivate func updatedSession(
    with cursor: OrbitPhase1ReplayCursor
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: scope,
      replayCursor: cursor,
      connectedAt: connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_500)
    )
  }
}

private func sampleSnapshot(
  cursorEventID: UUID
) -> OrbitPhase1RealtimeSnapshot {
  let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
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

private func sampleMeetingSnapshot(
  cursorEventID: UUID,
  status: OrbitMeetingStatus,
  outcomeState: OrbitMeetingOutcomeState,
  summaryBody: String
) -> OrbitPhase1RealtimeSnapshot {
  let baseline = sampleSnapshot(cursorEventID: cursorEventID)
  let createdAt = Date(timeIntervalSince1970: 1_742_342_500)
  let completedAt =
    status == .completed
    ? Date(timeIntervalSince1970: 1_742_342_540)
    : nil
  let postID = baseline.room.post.id
  let participantID = UUID(uuidString: "56565656-5656-5656-5656-565656565656")!
  let room = OrbitPhase1RoomSnapshot(
    workspace: baseline.room.workspace,
    channel: baseline.room.channel,
    workspacePersonas: baseline.room.workspacePersonas,
    post: OrbitPostRecord(
      id: postID,
      workspaceID: baseline.room.workspace.id,
      channelID: baseline.room.channel.id,
      postType: .meeting,
      createdByParticipantType: .user,
      createdByParticipantID: "aj",
      title: "Founding Group Meeting",
      status: .active,
      createdAt: createdAt
    ),
    thread: OrbitThreadRecord(
      id: baseline.room.thread.id,
      postID: postID,
      status: .open,
      lastActivityAt: completedAt ?? createdAt,
      createdAt: createdAt
    ),
    messages: baseline.room.messages,
    postParticipants: [
      OrbitPostParticipantRecord(
        id: participantID,
        postID: postID,
        participantType: .workspacePersona,
        participantID: "workspace-persona-orbit-samwise",
        joinedAt: createdAt,
        participationMode: .active
      )
    ],
    notes: [
      OrbitNoteRecord(
        id: UUID(uuidString: "57575757-5757-5757-5757-575757575757")!,
        postID: postID,
        noteType: .meetingSummary,
        body: summaryBody,
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system",
        createdAt: createdAt
      )
    ],
    decisions: [
      OrbitDecisionRecord(
        id: UUID(uuidString: "58585858-5858-5858-5858-585858585858")!,
        postID: postID,
        title: "Ship packet 4",
        body: "Keep meeting outputs inspectable after reload.",
        decisionState: .adopted,
        createdAt: completedAt ?? createdAt
      )
    ],
    references: [
      OrbitReferenceRecord(
        id: UUID(uuidString: "59595959-5959-5959-5959-595959595959")!,
        postID: postID,
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
        title: "Packet scope",
        createdAt: completedAt ?? createdAt
      )
    ],
    meetingOutputState: OrbitMeetingOutputStateRecord(
      postID: postID,
      outcomeState: outcomeState,
      recordedByParticipantType: .user,
      recordedByParticipantID: "aj",
      recordedAt: completedAt ?? createdAt
    ),
    meetingOpenQuestions: [
      OrbitMeetingOpenQuestionRecord(
        id: UUID(uuidString: "5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a")!,
        postID: postID,
        body: "How should edits work?",
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        createdAt: completedAt ?? createdAt
      )
    ],
    meetingState: OrbitMeetingStateRecord(
      postID: postID,
      meetingType: .team,
      status: status,
      startedByParticipantType: .user,
      startedByParticipantID: "aj",
      startedAt: createdAt,
      completedAt: completedAt
    ),
    meetingMembers: [
      OrbitMeetingMemberRecord(
        id: UUID(uuidString: "5b5b5b5b-5b5b-5b5b-5b5b-5b5b5b5b5b5b")!,
        meetingPostID: postID,
        postParticipantID: participantID,
        participationRole: .contributor,
        selectedReason: "Selected from founding-group scope.",
        joinedAt: createdAt
      )
    ]
  )

  return OrbitPhase1RealtimeSnapshot(
    room: room,
    replayCursor: baseline.replayCursor
  )
}
