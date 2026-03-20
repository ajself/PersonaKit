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
}
