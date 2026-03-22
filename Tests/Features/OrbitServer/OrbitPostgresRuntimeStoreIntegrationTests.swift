import Foundation
import Testing

@testable import OrbitServerRuntime

@Suite("Orbit Postgres Runtime Store Integration Tests", .serialized)
struct OrbitPostgresRuntimeStoreIntegrationTests {
  @Test
  func liveRuntimeStoreRoundTripWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleRoomBootstrap()

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let bootstrappedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug
      )

      let message = OrbitMessageRecord(
        id: UUID(),
        postID: room.post.id,
        threadID: room.thread.id,
        authorType: .user,
        authorID: "aj",
        body: "Live Postgres append proof",
        messageFormat: .plainText,
        state: .persisted,
        createdAt: Date(timeIntervalSince1970: 1_742_342_520),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
      )
      let realtimeEvents = try OrbitPhase1RealtimeEventProjector.appendEvents(
        workspaceID: room.workspace.id,
        message: message,
        threadLastActivityAt: message.createdAt
      )

      try await store.appendMessage(
        workspaceID: room.workspace.id,
        message,
        realtimeEvents: realtimeEvents,
        threadLastActivityAt: message.createdAt
      )

      let loadedEvents = try await store.loadRealtimeEvents(
        workspaceID: room.workspace.id,
        after: nil
      )
      let updatedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug
      )

      #expect(bootstrappedSnapshot?.messages.count == room.seedMessages.count)
      #expect(updatedSnapshot?.messages.count == room.seedMessages.count + 1)
      #expect(updatedSnapshot?.messages.last?.body == "Live Postgres append proof")
      #expect(loadedEvents.contains { $0.id == message.id && $0.category == .messageCreated })
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreSupportsCurrentOrbitMutationRingWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleRoomBootstrap()
      let workspacePersonaID = try #require(room.workspacePersonas.first?.id)
      let triggerMessageID = try #require(room.seedMessages.first?.id)

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let userMessageDate = Date(timeIntervalSince1970: 1_742_342_520)
      let userMessageID = UUID()
      let userWriteService = OrbitPhase1RoomWriteService(
        runtimeStore: store,
        now: { userMessageDate },
        makeMessageID: { userMessageID }
      )

      let userAppend = try await userWriteService.appendUserMessage(
        OrbitPhase1AppendUserMessageRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          authorID: "aj",
          body: "Live Postgres user append proof"
        )
      )

      let systemMessageDate = Date(timeIntervalSince1970: 1_742_342_521)
      let systemMessageID = UUID()
      let systemMessageService = OrbitPhase1SystemMessageService(
        runtimeStore: store,
        now: { systemMessageDate },
        makeMessageID: { systemMessageID }
      )

      let systemAppend = try await systemMessageService.appendSystemMessage(
        OrbitPhase1AppendSystemMessageRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          body: "Live Postgres system event proof",
          replyToMessageID: userAppend.message.id
        )
      )

      let collaboratorResponseDate = Date(timeIntervalSince1970: 1_742_342_522)
      let collaboratorMessageID = UUID()
      let activationID = UUID()
      let agentRunID = UUID()
      let collaboratorPostEventID = UUID()
      let collaboratorService = OrbitPhase1CollaboratorResponseService(
        runtimeStore: store,
        now: { collaboratorResponseDate },
        makeMessageID: { collaboratorMessageID },
        makeActivationID: { activationID },
        makeAgentRunID: { agentRunID },
        makePostEventID: { collaboratorPostEventID }
      )

      let collaboratorAppend = try await collaboratorService.appendCollaboratorResponse(
        OrbitPhase1AppendCollaboratorResponseRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          workspacePersonaID: workspacePersonaID,
          initiatedByParticipantID: "aj",
          triggerMessageID: userAppend.message.id,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          responseMode: .directAddress,
          body: "Live Postgres collaborator response proof",
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

      let activationFailureDate = Date(timeIntervalSince1970: 1_742_342_523)
      let activationFailurePostEventID = UUID()
      let activationFailureSystemMessageID = UUID()
      let activationFailureService = OrbitPhase1ActivationFailureService(
        runtimeStore: store,
        now: { activationFailureDate },
        makePostEventID: { activationFailurePostEventID }
      )

      let activationFailureAppend = try await activationFailureService.appendActivationFailure(
        OrbitPhase1AppendActivationFailureRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          initiatedByParticipantID: "aj",
          triggerMessageID: triggerMessageID,
          failure: OrbitPhase1ActivationFailurePayload(
            addressedTargetID: "samwise",
            participantID: "samwise",
            workspacePersonaID: workspacePersonaID.uuidString,
            personaTemplateID: "samwise",
            directiveID: "maintain-partner-sync-and-handoffs",
            triggerSource: "directAddress",
            systemEventMessageID: activationFailureSystemMessageID,
            requiredSkillIDs: ["codex-cli"],
            authorizedSkillIDs: ["codex-cli"],
            failureReason: "missingDirective",
            systemEventBody: "Live Postgres activation failure proof"
          )
        )
      )

      let updatedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug
      )
      let loadedEvents = try await store.loadRealtimeEvents(
        workspaceID: room.workspace.id,
        after: nil
      )

      #expect(updatedSnapshot?.messages.count == room.seedMessages.count + 4)
      #expect(updatedSnapshot?.messages.contains { $0.id == userAppend.message.id } == true)
      #expect(updatedSnapshot?.messages.contains { $0.id == systemAppend.message.id } == true)
      #expect(updatedSnapshot?.messages.contains { $0.id == collaboratorAppend.message.id } == true)
      #expect(updatedSnapshot?.messages.contains { $0.id == activationFailureAppend.systemMessage.id } == true)
      #expect(updatedSnapshot?.postEvents.map(\.id) == [collaboratorPostEventID, activationFailurePostEventID])
      #expect(updatedSnapshot?.personaActivations.map(\.id) == [activationID])
      #expect(updatedSnapshot?.agentRuns.map(\.id) == [agentRunID])
      #expect(loadedEvents.contains { $0.id == userAppend.message.id && $0.category == .messageCreated })
      #expect(loadedEvents.contains { $0.id == systemAppend.message.id && $0.category == .messageCreated })
      #expect(loadedEvents.contains { $0.id == collaboratorAppend.message.id && $0.category == .messageCreated })
      #expect(loadedEvents.contains { $0.id == collaboratorPostEventID && $0.category == .activationResolved })
      #expect(loadedEvents.contains { $0.id == activationFailurePostEventID && $0.category == .activationFailed })
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreRoundTripsMeetingRecordsWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleMeetingRoomBootstrap()

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let bootstrappedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug
      )

      #expect(bootstrappedSnapshot?.meetingState == room.meetingState)
      #expect(bootstrappedSnapshot?.meetingMembers == room.meetingMembers)
      #expect(bootstrappedSnapshot?.notes == room.notes)
      #expect(bootstrappedSnapshot?.meetingOutputState == room.meetingOutputState)

      let userMessageDate = Date(timeIntervalSince1970: 1_742_342_520)
      let userMessageID = UUID()
      let userWriteService = OrbitPhase1RoomWriteService(
        runtimeStore: store,
        now: { userMessageDate },
        makeMessageID: { userMessageID }
      )

      let appendResult = try await userWriteService.appendUserMessage(
        OrbitPhase1AppendUserMessageRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          authorID: "aj",
          body: "Meeting runtime activation proof"
        )
      )

      let updatedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug
      )

      #expect(appendResult.snapshot.meetingState?.status == .active)
      #expect(updatedSnapshot?.meetingState?.status == .active)
      #expect(updatedSnapshot?.meetingMembers == room.meetingMembers)
      #expect(appendResult.snapshot.notes == room.notes)
      #expect(updatedSnapshot?.notes == room.notes)
      #expect(appendResult.snapshot.meetingOutputState == room.meetingOutputState)
      #expect(updatedSnapshot?.meetingOutputState == room.meetingOutputState)
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreRoundTripsMeetingCompletionBundleWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleMeetingRoomBootstrap()
      let completionDate = Date(timeIntervalSince1970: 1_742_342_560)
      let decisionID = UUID(uuidString: "55555555-1111-2222-3333-444444444444")!
      let referenceID = UUID(uuidString: "66666666-1111-2222-3333-444444444444")!
      let openQuestionID = UUID(uuidString: "77777777-1111-2222-3333-444444444444")!
      let postEventID = UUID(uuidString: "88888888-1111-2222-3333-444444444444")!

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let completionService = OrbitPhase1MeetingCompletionService(
        runtimeStore: store,
        now: { completionDate },
        makeDecisionID: { decisionID },
        makeReferenceID: { referenceID },
        makeMeetingOpenQuestionID: { openQuestionID },
        makePostEventID: { postEventID }
      )

      let completionResult = try await completionService.completeMeeting(
        OrbitPhase1CompleteMeetingRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          postID: room.post.id,
          summaryBody: "Live Postgres completion proof",
          outcome: .decision,
          decisionTitle: "Ship the meeting outputs card",
          decisionBody: "Keep the first durable output bundle inspectable after reload.",
          openQuestions: ["How should follow-up edits work?"],
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
      let loadedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug,
        postID: room.post.id
      )
      let loadedEvents = try await store.loadRealtimeEvents(
        workspaceID: room.workspace.id,
        after: nil
      )

      #expect(completionResult.summaryNote.id == room.notes.first?.id)
      #expect(completionResult.summaryNote.body == "Live Postgres completion proof")
      #expect(completionResult.meetingOutputState.outcomeState == .decisionRecorded)
      #expect(completionResult.decision?.id == decisionID)
      #expect(completionResult.references.map(\.id) == [referenceID])
      #expect(completionResult.meetingOpenQuestions.map(\.id) == [openQuestionID])
      #expect(loadedSnapshot?.meetingState?.status == .completed)
      #expect(loadedSnapshot?.meetingState?.completedAt == completionDate)
      #expect(loadedSnapshot?.notes.first?.body == "Live Postgres completion proof")
      #expect(loadedSnapshot?.meetingOutputState?.outcomeState == .decisionRecorded)
      #expect(loadedSnapshot?.decisions.map(\.id) == [decisionID])
      #expect(loadedSnapshot?.references.map(\.id) == [referenceID])
      #expect(loadedSnapshot?.meetingOpenQuestions.map(\.id) == [openQuestionID])
      #expect(loadedEvents.contains { $0.id == postEventID && $0.category == .meetingOutputCommitted })
    } catch {
      Issue.record("Unexpected live Postgres meeting completion error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreLoadsPromotionPostLinksForOriginAndMeetingSnapshotsWhenDatabaseEnvironmentIsAvailable()
    async throws
  {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let originRoom = sampleRoomBootstrap()
      let meetingRoom = samplePromotedMeetingRoomBootstrap(originRoom: originRoom)
      let promotionLink = try #require(meetingRoom.postLinks.first)

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(originRoom)
      try await store.bootstrapRoom(meetingRoom)

      let originSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: originRoom.workspace.slug,
        channelSlug: originRoom.channel.slug,
        postID: originRoom.post.id
      )
      let promotedMeetingSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: meetingRoom.workspace.slug,
        channelSlug: meetingRoom.channel.slug,
        postID: meetingRoom.post.id
      )

      #expect(originSnapshot?.postLinks == [promotionLink])
      #expect(promotedMeetingSnapshot?.postLinks == [promotionLink])
    } catch {
      Issue.record("Unexpected live Postgres post-link error: \(String(reflecting: error))")
    }
  }

  private func integrationConfiguration() -> OrbitPostgresConfiguration? {
    let env = ProcessInfo.processInfo.environment

    guard
      let host = env["ORBIT_PG_HOST"],
      let username = env["ORBIT_PG_USER"],
      let password = env["ORBIT_PG_PASSWORD"],
      let database = env["ORBIT_PG_DATABASE"]
    else {
      return nil
    }

    let port = env["ORBIT_PG_PORT"].flatMap(Int.init) ?? 5432

    return OrbitPostgresConfiguration(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database
    )
  }

  private func sampleRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let workspaceID = UUID()
    let channelID = UUID()
    let postID = UUID()
    let threadID = UUID()
    let workspacePersonaID = UUID()
    let seedMessageID = UUID()
    let participantID = UUID()
    let baseDate = Date(timeIntervalSince1970: 1_742_342_400)
    let slugSuffix = UUID().uuidString.lowercased()

    return OrbitPhase1RoomBootstrap(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit-integration-\(slugSuffix)",
        name: "Orbit Integration",
        status: .active,
        createdAt: baseDate
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center-\(slugSuffix)",
        name: "Command Center",
        purpose: "Integration test room",
        status: .active,
        createdAt: baseDate
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: workspacePersonaID,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: baseDate
        )
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Integration room",
        status: .active,
        createdAt: baseDate
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: baseDate,
        createdAt: baseDate
      ),
      seedMessages: [
        OrbitMessageRecord(
          id: seedMessageID,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Integration bootstrap",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: baseDate,
          updatedAt: baseDate
        )
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: participantID,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: baseDate,
          participationMode: .active
        )
      ]
    )
  }

  private func sampleMeetingRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let bootstrap = sampleRoomBootstrap()
    let participantID = bootstrap.postParticipants[0].id

    return OrbitPhase1RoomBootstrap(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      post: OrbitPostRecord(
        id: bootstrap.post.id,
        workspaceID: bootstrap.post.workspaceID,
        channelID: bootstrap.post.channelID,
        postType: .meeting,
        createdByParticipantType: bootstrap.post.createdByParticipantType,
        createdByParticipantID: bootstrap.post.createdByParticipantID,
        title: bootstrap.post.title,
        status: bootstrap.post.status,
        createdAt: bootstrap.post.createdAt,
        archivedAt: bootstrap.post.archivedAt
      ),
      thread: bootstrap.thread,
      seedMessages: bootstrap.seedMessages,
      postParticipants: bootstrap.postParticipants,
      notes: [
        OrbitNoteRecord(
          id: UUID(),
          postID: bootstrap.post.id,
          noteType: .meetingSummary,
          body: "Summary pending.",
          createdByParticipantType: .system,
          createdByParticipantID: "orbit-system",
          createdAt: bootstrap.post.createdAt
        )
      ],
      meetingOutputState: OrbitMeetingOutputStateRecord(
        postID: bootstrap.post.id,
        outcomeState: .pending,
        recordedByParticipantType: .system,
        recordedByParticipantID: "orbit-system",
        recordedAt: bootstrap.post.createdAt
      ),
      meetingState: OrbitMeetingStateRecord(
        postID: bootstrap.post.id,
        meetingType: .team,
        status: .created,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: bootstrap.post.createdAt
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(),
          meetingPostID: bootstrap.post.id,
          postParticipantID: participantID,
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: bootstrap.post.createdAt
        )
      ]
    )
  }

  private func samplePromotedMeetingRoomBootstrap(
    originRoom: OrbitPhase1RoomBootstrap
  ) -> OrbitPhase1RoomBootstrap {
    let meetingPostID = UUID()
    let meetingThreadID = UUID()
    let meetingParticipantID = UUID()
    let meetingSeedMessageID = UUID()
    let meetingMemberID = UUID()
    let promotionLinkID = UUID()
    let createdAt = originRoom.post.createdAt.addingTimeInterval(60)

    return OrbitPhase1RoomBootstrap(
      workspace: originRoom.workspace,
      channel: originRoom.channel,
      workspacePersonas: originRoom.workspacePersonas,
      post: OrbitPostRecord(
        id: meetingPostID,
        workspaceID: originRoom.workspace.id,
        channelID: originRoom.channel.id,
        postType: .meeting,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Promoted meeting room",
        status: .active,
        createdAt: createdAt
      ),
      thread: OrbitThreadRecord(
        id: meetingThreadID,
        postID: meetingPostID,
        status: .open,
        lastActivityAt: createdAt,
        createdAt: createdAt
      ),
      seedMessages: [
        OrbitMessageRecord(
          id: meetingSeedMessageID,
          postID: meetingPostID,
          threadID: meetingThreadID,
          authorType: .user,
          authorID: "aj",
          body: "Promoted meeting room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: createdAt,
          updatedAt: createdAt
        )
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: meetingParticipantID,
          postID: meetingPostID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: createdAt,
          participationMode: .active
        )
      ],
      postLinks: [
        OrbitPostLinkRecord(
          id: promotionLinkID,
          fromPostID: originRoom.post.id,
          toPostID: meetingPostID,
          linkType: .promotion,
          createdAt: createdAt
        )
      ],
      notes: [
        OrbitNoteRecord(
          id: UUID(),
          postID: meetingPostID,
          noteType: .meetingSummary,
          body: "Summary pending.",
          createdByParticipantType: .system,
          createdByParticipantID: "orbit-system",
          createdAt: createdAt
        )
      ],
      meetingState: OrbitMeetingStateRecord(
        postID: meetingPostID,
        meetingType: .team,
        status: .created,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: createdAt
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: meetingMemberID,
          meetingPostID: meetingPostID,
          postParticipantID: meetingParticipantID,
          participationRole: .contributor,
          selectedReason: "Selected via explicit promotion.",
          joinedAt: createdAt
        )
      ]
    )
  }
}
