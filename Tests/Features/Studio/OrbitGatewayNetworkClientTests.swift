import Foundation
import Synchronization
import Testing

@testable import OrbitServerGateway
@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitGatewayNetworkClientTests {
  @Test
  func connectDecodesBootstrapTransportFromGateway() async throws {
    let snapshot = sampleSnapshot()
    let session = sampleSession(snapshot: snapshot)
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/realtime/connect")
      let body = try JSONDecoder().decode(
        OrbitGatewayConnectRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.workspaceSlug == "orbit")
      #expect(body.channelSlug == "command-center")
      #expect(body.postID == UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayTransportResponse(
          response: .bootstrap(session, snapshot)
        ),
        url: try #require(request.url)
      )
    }

    let response = try await client.connect(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        )
      )
    )

    #expect(response == .bootstrap(session, snapshot))
  }

  @Test
  func pollEncodesSessionDatesAsISO8601ForGatewayHTTPRoutes() async throws {
    let snapshot = sampleSnapshot()
    let session = sampleSession(snapshot: snapshot)
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/realtime/poll")
      let body = try httpDecoder.decode(
        OrbitGatewayPollRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.session.workspaceSlug == "orbit")
      #expect(body.session.channelSlug == "command-center")
      #expect(body.session.cursorEventCreatedAt == snapshot.replayCursor.lastEventCreatedAt)
      #expect(body.session.connectedAt == session.connectedAt)
      #expect(body.session.lastInteractionAt == session.lastInteractionAt)

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayTransportResponse(response: .noChange(session)),
        url: try #require(request.url)
      )
    }

    let response = try await client.poll(
      request: OrbitPhase1RealtimePollRequest(session: session)
    )

    #expect(response == .noChange(session))
  }

  @Test
  func persistentTransportResponsesSendBootstrapThenPollOverTheSameSocket() async throws {
    let snapshot = sampleSnapshot()
    let bootstrapSession = sampleSession(snapshot: snapshot)
    let handshakeURL = CapturedURLBox()
    let polledSession = OrbitPhase1RealtimeSession(
      scope: bootstrapSession.scope,
      replayCursor: bootstrapSession.replayCursor,
      connectedAt: bootstrapSession.connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_430)
    )
    let socket = StubSocket(
      receivedTexts: [
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .bootstrap(bootstrapSession, snapshot)
          )
        ),
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .noChange(polledSession)
          )
        ),
      ]
    )
    let sleep = StubSleep(maxSleepsBeforeCancellation: 1)
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, url in
        handshakeURL.set(url)
        return socket
      },
      sleep: { duration in
        try await sleep.pause(for: duration)
      }
    )

    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        )
      ),
      pollInterval: Duration.seconds(2)
    )
    var iterator = responses.makeAsyncIterator()
    let bootstrapResponse = try await iterator.next()
    let pollResponse = try await iterator.next()

    #expect(bootstrapResponse == .bootstrap(bootstrapSession, snapshot))
    #expect(pollResponse == .noChange(polledSession))

    let sentMessages = await socket.sentTexts
    let bootstrapMessage = try JSONDecoder().decode(
      OrbitGatewayWebSocketClientMessage.self,
      from: Data(try #require(sentMessages.first).utf8)
    )
    let pollMessage = try JSONDecoder().decode(
      OrbitGatewayWebSocketClientMessage.self,
      from: Data(try #require(sentMessages.last).utf8)
    )

    #expect(bootstrapMessage.kind == .bootstrap)
    #expect(bootstrapMessage.session == nil)
    #expect(pollMessage.kind == .poll)
    #expect(pollMessage.session?.workspaceSlug == "orbit")
    #expect(pollMessage.session?.cursorEventID == snapshot.replayCursor.lastEventID)
    #expect(await socket.cancelCallCount == 1)
    let queryItems = URLComponents(
      url: try #require(handshakeURL.current),
      resolvingAgainstBaseURL: false
    )?.queryItems
    #expect(queryItems?.contains(URLQueryItem(name: "workspaceSlug", value: "orbit")) == true)
    #expect(queryItems?.contains(URLQueryItem(name: "channelSlug", value: "command-center")) == true)
    #expect(
      queryItems?.contains(
        URLQueryItem(
          name: "postID",
          value: "33333333-3333-3333-3333-333333333333"
        )
      ) == true
    )
  }

  @Test
  func persistentTransportResponsesEncodesReplayCursorTimestampAsEpochSeconds() async throws {
    let snapshot = sampleSnapshot()
    let handshakeURL = CapturedURLBox()
    let socket = StubSocket(
      receivedTexts: [
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .bootstrap(sampleSession(snapshot: snapshot), snapshot)
          )
        )
      ]
    )
    let sleep = StubSleep(maxSleepsBeforeCancellation: 0)
    let cursorDate = Date(timeIntervalSince1970: 1_742_342_460)
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, url in
        handshakeURL.set(url)
        return socket
      },
      sleep: { duration in
        try await sleep.pause(for: duration)
      }
    )

    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        ),
        cursor: OrbitPhase1ReplayCursor(
          workspaceID: snapshot.replayCursor.workspaceID,
          lastEventID: snapshot.replayCursor.lastEventID,
          lastEventCreatedAt: cursorDate
        )
      )
    )
    var iterator = responses.makeAsyncIterator()

    _ = try await iterator.next()

    let handshakeURLValue = try #require(handshakeURL.current)
    let queryItems = try #require(
      URLComponents(
        url: handshakeURLValue,
        resolvingAgainstBaseURL: false
      )?.queryItems
    )
    #expect(
      queryItems.contains(
        URLQueryItem(
          name: "cursorEventCreatedAt",
          value: String(cursorDate.timeIntervalSince1970)
        )
      )
    )
  }

  @Test
  func persistentTransportResponsesSurfaceGatewaySocketRejection() async throws {
    let socket = StubSocket(
      receivedTexts: ["{\"kind\":\"error\"}"]
    )
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, _ in socket },
      sleep: { _ in
        try await Task.sleep(for: .zero)
      }
    )
    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        )
      )
    )
    var iterator = responses.makeAsyncIterator()

    do {
      _ = try await iterator.next()
      Issue.record("Expected socket rejection")
    } catch let error as OrbitGatewayNetworkClientError {
      switch error {
      case .socketRejectedRequest:
        break
      case .invalidHTTPResponse,
        .unexpectedStatusCode,
        .invalidSocketURL,
        .invalidSocketMessage:
        Issue.record("Expected socket rejection, got \(error)")
      }
    }
  }

  @Test
  func appendCollaboratorResponseSendsContractAndDecodesCanonicalResult() async throws {
    let result = sampleCollaboratorResult()
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/responses")
      let body = try JSONDecoder().decode(
        OrbitGatewayAppendCollaboratorResponseRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.workspaceSlug == "orbit")
      #expect(body.postID == result.snapshot.post.id)
      #expect(body.contract?.authorizedSkillIDs == ["codex-cli"])
      #expect(body.contract?.reviewGateIDs == ["intent:partner-sync-review"])

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayAppendCollaboratorResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.appendCollaboratorResponse(
      OrbitPhase1AppendCollaboratorResponseRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: result.snapshot.post.id,
        workspacePersonaID: result.activation.resolvedWorkspacePersonaInstanceID,
        initiatedByParticipantID: "aj",
        triggerMessageID: result.activation.triggerMessageID,
        addressedTargetKind: .collaborator,
        addressedTargetReferenceID: result.activation.resolvedWorkspacePersonaInstanceID.uuidString,
        responseMode: .directAddress,
        body: result.message.body,
        contract: OrbitPhase1ResolvedContractPayload(
          directiveID: "maintain-partner-sync-and-handoffs",
          directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
          kitIDs: ["trusted-partner-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          stopPointIDs: [],
          reviewGateIDs: ["intent:partner-sync-review"],
          memoryScopeIDs: []
        )
      )
    )

    #expect(response == result)
  }

  @Test
  func appendMeetingPromotionEventEncodesRequestAndDecodesCanonicalResult() async throws {
    let result = OrbitPhase1AppendMeetingPromotionEventResult(
      snapshot: sampleSnapshot().room,
      postEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "89898989-8989-8989-8989-898989898989")!,
        postID: sampleSnapshot().room.post.id,
        threadID: sampleSnapshot().room.thread.id,
        eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_520)
      )
    )
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/meeting-promotions")
      let body = try JSONDecoder().decode(
        OrbitGatewayAppendMeetingPromotionEventRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.workspaceSlug == "orbit")
      #expect(body.promotion.addressedTargetReferenceID == "founding-group")
      #expect(body.promotion.failure == nil)

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayAppendMeetingPromotionEventResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.appendMeetingPromotionEvent(
      OrbitPhase1AppendMeetingPromotionEventRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: sampleSnapshot().room.post.id,
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

    #expect(response == result)
  }

  @Test
  func createMeetingRoomEncodesRequestAndDecodesCanonicalResult() async throws {
    let result = OrbitPhase1CreateMeetingRoomResult(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
      ),
      snapshot: sampleSnapshot().room
    )
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/meetings")
      let body = try JSONDecoder().decode(
        OrbitGatewayCreateMeetingRoomRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.title == "Founding Group Promotion")
      #expect(body.meetingType == OrbitMeetingType.team.rawValue)
      #expect(body.startedByParticipantType == OrbitParticipantAuthorType.user.rawValue)
      #expect(body.members.count == 1)

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayCreateMeetingRoomResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.createMeetingRoom(
      OrbitPhase1CreateMeetingRoomRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        title: "Founding Group Promotion",
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
      )
    )

    #expect(response == result)
  }

  @Test
  func completeMeetingEncodesRequestAndDecodesCanonicalResult() async throws {
    let snapshot = sampleSnapshot()
    let result = OrbitPhase1CompleteMeetingResult(
      snapshot: snapshot.room,
      summaryNote: OrbitNoteRecord(
        id: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!,
        postID: snapshot.room.post.id,
        noteType: .meetingSummary,
        body: "Completed summary",
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system",
        createdAt: Date(timeIntervalSince1970: 1_742_342_530)
      ),
      meetingOutputState: OrbitMeetingOutputStateRecord(
        postID: snapshot.room.post.id,
        outcomeState: .decisionRecorded,
        recordedByParticipantType: .user,
        recordedByParticipantID: "aj",
        recordedAt: Date(timeIntervalSince1970: 1_742_342_530)
      ),
      decision: OrbitDecisionRecord(
        id: UUID(uuidString: "31313131-3131-3131-3131-313131313131")!,
        postID: snapshot.room.post.id,
        title: "Ship packet 4 shell",
        body: "Persist meeting outputs through replay and reload.",
        decisionState: .adopted,
        createdAt: Date(timeIntervalSince1970: 1_742_342_530)
      ),
      references: [
        OrbitReferenceRecord(
          id: UUID(uuidString: "32323232-3232-3232-3232-323232323232")!,
          postID: snapshot.room.post.id,
          referenceType: .doc,
          target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
          title: "Packet scope",
          createdAt: Date(timeIntervalSince1970: 1_742_342_531)
        )
      ],
      meetingOpenQuestions: [
        OrbitMeetingOpenQuestionRecord(
          id: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!,
          postID: snapshot.room.post.id,
          body: "How should edits work?",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: Date(timeIntervalSince1970: 1_742_342_530)
        )
      ],
      postEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        eventType: OrbitPhase1RealtimeEventCategory.meetingOutputCommitted.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_530)
      )
    )
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/meeting-completions")
      let body = try JSONDecoder().decode(
        OrbitGatewayCompleteMeetingRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.summaryBody == "Completed summary")
      #expect(body.outcome == OrbitPhase1MeetingCompletionOutcome.decision.rawValue)
      #expect(body.decisionTitle == "Ship packet 4 shell")
      #expect(body.openQuestions == ["How should edits work?"])
      #expect(body.followUpReferences.first?.referenceType == OrbitReferenceType.doc.rawValue)
      #expect(body.completedByParticipantType == OrbitParticipantAuthorType.user.rawValue)

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayCompleteMeetingResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.completeMeeting(
      OrbitPhase1CompleteMeetingRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: snapshot.room.post.id,
        summaryBody: "Completed summary",
        outcome: .decision,
        decisionTitle: "Ship packet 4 shell",
        decisionBody: "Persist meeting outputs through replay and reload.",
        openQuestions: ["How should edits work?"],
        followUpReferences: [
          OrbitPhase1MeetingReferenceSpec(
            referenceType: .doc,
            target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
            title: "Packet scope"
          )
        ],
        completedByParticipantType: .user,
        completedByParticipantID: "aj"
      )
    )

    #expect(response == result)
  }

  @Test
  func promoteMeetingRoomEncodesRequestAndDecodesCanonicalResult() async throws {
    let result = OrbitPhase1PromoteMeetingRoomResult(
      meeting: OrbitPhase1CreateMeetingRoomResult(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        ),
        snapshot: sampleSnapshot().room
      ),
      originPostEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        postID: sampleSnapshot().room.post.id,
        threadID: sampleSnapshot().room.thread.id,
        eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_520)
      )
    )
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/promoted-meetings")
      let body = try JSONDecoder().decode(
        OrbitGatewayPromoteMeetingRoomRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.originPostID == sampleSnapshot().room.post.id)
      #expect(body.meeting.title == "Founding Group Promotion")
      #expect(body.meeting.meetingType == OrbitMeetingType.team.rawValue)
      #expect(body.promotion.addressedTargetReferenceID == "founding-group")

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayPromoteMeetingRoomResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.promoteMeetingRoom(
      OrbitPhase1PromoteMeetingRoomRequest(
        originPostID: sampleSnapshot().room.post.id,
        meeting: OrbitPhase1CreateMeetingRoomRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          title: "Founding Group Promotion",
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
          title: "Founding Group Promotion",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
          ]
        )
      )
    )

    #expect(response == result)
  }

  @Test
  func connectThrowsHelpfulErrorForGatewayFailure() async throws {
    let client = makeClient { request in
      try makeResponse(
        statusCode: 503,
        body: Data("gateway offline".utf8),
        url: try #require(request.url)
      )
    }

    do {
      _ = try await client.connect(
        request: OrbitPhase1RealtimeConnectRequest(
          scope: OrbitPhase1RealtimeSubscriptionScope(
            workspaceSlug: "orbit",
            channelSlug: "command-center"
          )
        )
      )
      Issue.record("Expected gateway failure")
    } catch let error as OrbitGatewayNetworkClientError {
      switch error {
      case .unexpectedStatusCode(let statusCode, let body):
        #expect(statusCode == 503)
        #expect(body == "gateway offline")
      case .invalidHTTPResponse:
        Issue.record("Expected HTTP status failure, not invalid response")
      case .invalidSocketURL,
        .invalidSocketMessage,
        .socketRejectedRequest:
        Issue.record("Expected HTTP status failure, got \(error)")
      }
    }
  }

  private func makeClient(
    handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
  ) -> OrbitGatewayNetworkClient {
    let host = "orbit-\(UUID().uuidString.lowercased())"
    TestURLProtocol.handlerBox.set(handler, forHost: host)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TestURLProtocol.self]

    return OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://\(host)")!,
      session: URLSession(configuration: configuration)
    )
  }

  private func makeResponse<ResponseBody: Encodable>(
    statusCode: Int,
    body: ResponseBody,
    url: URL
  ) throws -> (HTTPURLResponse, Data) {
    (
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!,
      try httpEncoder.encode(body)
    )
  }

  private func makeResponse(
    statusCode: Int,
    body: Data,
    url: URL
  ) throws -> (HTTPURLResponse, Data) {
    (
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "text/plain"]
      )!,
      body
    )
  }

  private var httpEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private var httpDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private func makeSocketPayload(
    _ payload: OrbitGatewayTransportResponse
  ) throws -> String {
    String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
  }

  private func sampleSession(
    snapshot: OrbitPhase1RealtimeSnapshot
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    return OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
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
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
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
          lastActivityAt: Date(timeIntervalSince1970: 1_742_342_400),
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
        messages: []
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: nil,
        lastEventCreatedAt: nil
      )
    )
  }

  private func sampleCollaboratorResult() -> OrbitPhase1AppendCollaboratorResponseResult {
    let snapshot = sampleSnapshot()
    let workspacePersonaID = snapshot.room.workspacePersonas[0].id
    let triggerMessageID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let message = OrbitMessageRecord(
      id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
      postID: snapshot.room.post.id,
      threadID: snapshot.room.thread.id,
      authorType: .workspacePersona,
      authorID: workspacePersonaID.uuidString,
      replyToMessageID: triggerMessageID,
      body: "Canonical collaborator response",
      messageFormat: .markdown,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_510),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_510)
    )
    let activation = OrbitPersonaActivationRecord(
      id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
      initiatedByParticipantType: .user,
      initiatedByParticipantID: "aj",
      workspaceID: snapshot.room.workspace.id,
      channelID: snapshot.room.channel.id,
      originPostID: snapshot.room.post.id,
      originThreadID: snapshot.room.thread.id,
      triggerMessageID: triggerMessageID,
      addressedTargetKind: .collaborator,
      addressedTargetReferenceID: workspacePersonaID.uuidString,
      resolvedWorkspacePersonaInstanceID: workspacePersonaID,
      responseMode: .directAddress,
      createdAt: Date(timeIntervalSince1970: 1_742_342_510)
    )
    let agentRun = OrbitAgentRunRecord(
      id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
      personaActivationID: activation.id,
      runnerKind: "local-bridge",
      status: .completed,
      startedAt: Date(timeIntervalSince1970: 1_742_342_510),
      completedAt: Date(timeIntervalSince1970: 1_742_342_510)
    )

    return OrbitPhase1AppendCollaboratorResponseResult(
      snapshot: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: [message],
        personaActivations: [activation],
        agentRuns: [agentRun]
      ),
      message: message,
      activation: activation,
      agentRun: agentRun
    )
  }

  private func requestBody(
    for request: URLRequest
  ) throws -> Data {
    if let httpBody = request.httpBody {
      return httpBody
    }

    guard let stream = request.httpBodyStream else {
      throw URLError(.badServerResponse)
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var data = Data()

    while stream.hasBytesAvailable {
      let readCount = stream.read(buffer, maxLength: bufferSize)

      if readCount < 0 {
        throw stream.streamError ?? URLError(.cannotDecodeRawData)
      }

      if readCount == 0 {
        break
      }

      data.append(buffer, count: readCount)
    }

    return data
  }
}

private actor StubSocket: OrbitGatewaySocketHandling {
  private(set) var sentTexts = [String]()
  private var receivedTexts: [String]
  private(set) var cancelCallCount = 0

  init(
    receivedTexts: [String]
  ) {
    self.receivedTexts = receivedTexts
  }

  func send(
    text: String
  ) async throws {
    sentTexts.append(text)
  }

  func receiveText() async throws -> String {
    guard !receivedTexts.isEmpty else {
      throw URLError(.cannotParseResponse)
    }

    return receivedTexts.removeFirst()
  }

  func cancel() async {
    cancelCallCount += 1
  }
}

private actor StubSleep {
  private let maxSleepsBeforeCancellation: Int
  private var sleepCount = 0

  init(
    maxSleepsBeforeCancellation: Int
  ) {
    self.maxSleepsBeforeCancellation = maxSleepsBeforeCancellation
  }

  func pause(
    for _: Duration
  ) async throws {
    sleepCount += 1

    if sleepCount > maxSleepsBeforeCancellation {
      throw CancellationError()
    }
  }
}

private final class CapturedURLBox: Sendable {
  private let storage = Mutex<URL?>(nil)

  var current: URL? {
    storage.withLock { $0 }
  }

  func set(
    _ url: URL
  ) {
    storage.withLock { value in
      value = url
    }
  }
}

private final class TestURLProtocolHandlerBox: Sendable {
  private let handlers = Mutex<[String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)]>([:])

  func set(
    _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data),
    forHost host: String
  ) {
    handlers.withLock { currentHandlers in
      currentHandlers[host] = handler
    }
  }

  func current(
    forHost host: String
  ) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
    handlers.withLock { $0[host] }
  }
}

private final class TestURLProtocol: URLProtocol {
  static let handlerBox = TestURLProtocolHandlerBox()

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      guard
        let host = request.url?.host,
        let handler = Self.handlerBox.current(forHost: host)
      else {
        throw URLError(.badServerResponse)
      }
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
