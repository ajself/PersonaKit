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
  func liveRuntimeStoreRoundTripsApprovedMemoryRecordsWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleRoomBootstrap()
      let bundle = sampleApprovedMemoryRecordBundle(room: room)

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)
      try await store.recordApprovedMemory(bundle)

      let personaTemplateID = try #require(bundle.entry.personaTemplateID)
      let loadedCandidate = try await store.loadMemoryCandidate(id: bundle.candidate.id)
      let loadedReviews = try await store.loadMemoryReviews(
        memoryCandidateID: bundle.candidate.id
      )
      let loadedEntry = try await store.loadApprovedMemoryEntry(id: bundle.entry.id)
      let loadedPersonaGlobalProfile = try await store.loadPersonaGlobalMemoryProfile(
        personaTemplateID: personaTemplateID
      )

      #expect(loadedCandidate == bundle.candidate)
      #expect(loadedReviews == [bundle.review])
      #expect(loadedEntry == bundle.entry)
      #expect(loadedEntry?.sourceMemoryCandidateID == bundle.candidate.id)
      #expect(loadedPersonaGlobalProfile == bundle.personaGlobalProfile)
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreLoadsOnlyEligibleApprovedMemoryWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let primaryRoom = sampleRoomBootstrap()
      let sameTemplateRoom = sampleRoomBootstrap()
      let differentTemplateRoom = sampleRoomBootstrap(personaTemplateID: "venture-product-steward")
      let primaryPersona = primaryRoom.workspacePersonas[0]

      let workspaceBundle = approvedMemoryRecordBundle(
        room: primaryRoom,
        candidateID: UUID(uuidString: "d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1")!,
        reviewID: UUID(uuidString: "d2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2")!,
        entryID: UUID(uuidString: "d3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3")!,
        scope: .workspace,
        title: "Workspace norm",
        body: "This workspace keeps approved memory local.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_531)
      )
      let workspacePersonaBundle = approvedMemoryRecordBundle(
        room: primaryRoom,
        candidateID: UUID(uuidString: "d4d4d4d4-d4d4-d4d4-d4d4-d4d4d4d4d4d4")!,
        reviewID: UUID(uuidString: "d5d5d5d5-d5d5-d5d5-d5d5-d5d5d5d5d5d5")!,
        entryID: UUID(uuidString: "d6d6d6d6-d6d6-d6d6-d6d6-d6d6d6d6d6d6")!,
        scope: .workspacePersona,
        title: "Workspace persona habit",
        body: "This memory belongs only to the local Samwise instance.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_532)
      )
      let personaGlobalBundle = approvedMemoryRecordBundle(
        room: primaryRoom,
        candidateID: UUID(uuidString: "d7d7d7d7-d7d7-d7d7-d7d7-d7d7d7d7d7d7")!,
        reviewID: UUID(uuidString: "d8d8d8d8-d8d8-d8d8-d8d8-d8d8d8d8d8d8")!,
        entryID: UUID(uuidString: "d9d9d9d9-d9d9-d9d9-d9d9-d9d9d9d9d9d9")!,
        profileID: UUID(uuidString: "dadadada-dada-dada-dada-dadadadadada")!,
        scope: .personaGlobal,
        title: "Samwise global craft",
        body: "This expertise follows the Samwise template across workspaces.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_533),
        includePersonaGlobalProfile: true
      )
      let sameTemplatePersonaGlobalBundle = approvedMemoryRecordBundle(
        room: sameTemplateRoom,
        candidateID: UUID(uuidString: "dbdbdbdb-dbdb-dbdb-dbdb-dbdbdbdbdbdb")!,
        reviewID: UUID(uuidString: "dcdcdcdc-dcdc-dcdc-dcdc-dcdcdcdcdcdc")!,
        entryID: UUID(uuidString: "dddddddd-1111-2222-3333-444444444444")!,
        scope: .personaGlobal,
        title: "Cross-workspace Samwise expertise",
        body: "Persona-global memory remains eligible for the same template only.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_534)
      )
      let differentWorkspaceBundle = approvedMemoryRecordBundle(
        room: sameTemplateRoom,
        candidateID: UUID(uuidString: "dededede-dede-dede-dede-dededededede")!,
        reviewID: UUID(uuidString: "dfdfdfdf-dfdf-dfdf-dfdf-dfdfdfdfdfdf")!,
        entryID: UUID(uuidString: "e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0")!,
        scope: .workspace,
        title: "Other workspace norm",
        body: "A different workspace should stay isolated.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_535)
      )
      let differentWorkspacePersonaBundle = approvedMemoryRecordBundle(
        room: sameTemplateRoom,
        candidateID: UUID(uuidString: "e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1")!,
        reviewID: UUID(uuidString: "e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2")!,
        entryID: UUID(uuidString: "e3e3e3e3-e3e3-e3e3-e3e3-e3e3e3e3e3e3")!,
        scope: .workspacePersona,
        title: "Other workspace persona habit",
        body: "A different workspace persona should stay isolated.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_536)
      )
      let organizationBundle = approvedMemoryRecordBundle(
        room: primaryRoom,
        candidateID: UUID(uuidString: "e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4")!,
        reviewID: UUID(uuidString: "e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5")!,
        entryID: UUID(uuidString: "e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6")!,
        scope: .organization,
        title: "Organization memory",
        body: "Organization scope stays default-off in this repo posture.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_537)
      )
      let archivedBundle = approvedMemoryRecordBundle(
        room: primaryRoom,
        candidateID: UUID(uuidString: "e7e7e7e7-e7e7-e7e7-e7e7-e7e7e7e7e7e7")!,
        reviewID: UUID(uuidString: "e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8")!,
        entryID: UUID(uuidString: "e9e9e9e9-e9e9-e9e9-e9e9-e9e9e9e9e9e9")!,
        scope: .workspace,
        title: "Archived workspace memory",
        body: "Non-active approved memory should not be retrieved.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_538),
        status: .archived
      )
      let differentTemplateBundle = approvedMemoryRecordBundle(
        room: differentTemplateRoom,
        candidateID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        reviewID: UUID(uuidString: "efefefef-efef-efef-efef-efefefefefef")!,
        entryID: UUID(uuidString: "f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0")!,
        scope: .personaGlobal,
        title: "Other template global craft",
        body: "Different persona templates should not cross over.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_539)
      )

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(primaryRoom)
      try await store.bootstrapRoom(sameTemplateRoom)
      try await store.bootstrapRoom(differentTemplateRoom)

      for bundle in [
        workspaceBundle,
        workspacePersonaBundle,
        personaGlobalBundle,
        sameTemplatePersonaGlobalBundle,
        differentWorkspaceBundle,
        differentWorkspacePersonaBundle,
        organizationBundle,
        archivedBundle,
        differentTemplateBundle,
      ] {
        try await store.recordApprovedMemory(bundle)
      }

      let eligibleMemory = try await store.loadEligibleApprovedMemory(
        OrbitApprovedMemoryEligibilityRequest(
          workspaceID: primaryRoom.workspace.id,
          workspacePersonaID: primaryPersona.id,
          personaTemplateID: primaryPersona.personaTemplateID
        )
      )

      #expect(
        eligibleMemory.entries.map(\.id) == [
          workspaceBundle.entry.id,
          workspacePersonaBundle.entry.id,
          personaGlobalBundle.entry.id,
          sameTemplatePersonaGlobalBundle.entry.id,
        ]
      )
      #expect(eligibleMemory.personaGlobalProfile == personaGlobalBundle.personaGlobalProfile)
      #expect(eligibleMemory.entries.contains { $0.id == differentWorkspaceBundle.entry.id } == false)
      #expect(
        eligibleMemory.entries.contains { $0.id == differentWorkspacePersonaBundle.entry.id } == false
      )
      #expect(eligibleMemory.entries.contains { $0.id == organizationBundle.entry.id } == false)
      #expect(eligibleMemory.entries.contains { $0.id == archivedBundle.entry.id } == false)
      #expect(eligibleMemory.entries.contains { $0.id == differentTemplateBundle.entry.id } == false)
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreLoadsActivationTraceWithoutContractOrMemoryWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleRoomBootstrap()
      let workspacePersonaID = try #require(room.workspacePersonas.first?.id)
      let activationID = UUID(uuidString: "abababab-1111-2222-3333-444444444444")!
      let agentRunID = UUID(uuidString: "bcbcbcbc-1111-2222-3333-444444444444")!

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let collaboratorService = OrbitPhase1CollaboratorResponseService(
        runtimeStore: store,
        now: { Date(timeIntervalSince1970: 1_742_342_540) },
        makeMessageID: { UUID(uuidString: "cdcdcdcd-1111-2222-3333-444444444444")! },
        makeActivationID: { activationID },
        makeAgentRunID: { agentRunID },
        makePostEventID: { UUID(uuidString: "dededede-1111-2222-3333-444444444444")! }
      )

      _ = try await collaboratorService.appendCollaboratorResponse(
        OrbitPhase1AppendCollaboratorResponseRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          workspacePersonaID: workspacePersonaID,
          initiatedByParticipantID: "aj",
          triggerMessageID: room.seedMessages[0].id,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          responseMode: .directAddress,
          body: "Trace baseline with no contract or memory."
        )
      )

      let trace = try await store.loadActivationTrace(activationID: activationID)

      #expect(trace?.activation.id == activationID)
      #expect(trace?.contractSnapshot == nil)
      #expect(trace?.agentRuns.map(\.id) == [agentRunID])
      #expect(trace?.memory.isEmpty == true)
    } catch {
      Issue.record("Unexpected live Postgres error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreLoadsActivationTraceWithScopedMemoryAndMinimumLineageWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleRoomBootstrap()
      let workspacePersona = room.workspacePersonas[0]
      let activationID = UUID(uuidString: "efefefef-1111-2222-3333-444444444444")!
      let agentRunID = UUID(uuidString: "f0f0f0f0-1111-2222-3333-444444444444")!
      let workspaceBundle = approvedMemoryRecordBundle(
        room: room,
        candidateID: UUID(uuidString: "01010101-1111-2222-3333-444444444444")!,
        reviewID: UUID(uuidString: "02020202-1111-2222-3333-444444444444")!,
        entryID: UUID(uuidString: "03030303-1111-2222-3333-444444444444")!,
        scope: .workspace,
        title: "Workspace norm",
        body: "Scoped to the current workspace only.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_531)
      )
      let workspaceWithoutLineageBaseBundle = approvedMemoryRecordBundle(
        room: room,
        candidateID: UUID(uuidString: "04040404-1111-2222-3333-444444444444")!,
        reviewID: UUID(uuidString: "05050505-1111-2222-3333-444444444444")!,
        entryID: UUID(uuidString: "06060606-1111-2222-3333-444444444444")!,
        scope: .workspace,
        title: "Workspace note without ancestry",
        body: "Approved memory can exist without candidate ancestry.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_532)
      )
      let workspaceWithoutLineageBundle = OrbitApprovedMemoryRecordBundle(
        candidate: workspaceWithoutLineageBaseBundle.candidate,
        review: workspaceWithoutLineageBaseBundle.review,
        entry: OrbitMemoryEntryRecord(
          id: workspaceWithoutLineageBaseBundle.entry.id,
          scope: workspaceWithoutLineageBaseBundle.entry.scope,
          workspaceID: workspaceWithoutLineageBaseBundle.entry.workspaceID,
          workspacePersonaID: workspaceWithoutLineageBaseBundle.entry.workspacePersonaID,
          personaTemplateID: workspaceWithoutLineageBaseBundle.entry.personaTemplateID,
          title: workspaceWithoutLineageBaseBundle.entry.title,
          body: workspaceWithoutLineageBaseBundle.entry.body,
          status: workspaceWithoutLineageBaseBundle.entry.status,
          validFrom: workspaceWithoutLineageBaseBundle.entry.validFrom,
          validTo: workspaceWithoutLineageBaseBundle.entry.validTo,
          sourceMemoryCandidateID: nil,
          createdAt: workspaceWithoutLineageBaseBundle.entry.createdAt
        )
      )
      let workspacePersonaBundle = approvedMemoryRecordBundle(
        room: room,
        candidateID: UUID(uuidString: "07070707-1111-2222-3333-444444444444")!,
        reviewID: UUID(uuidString: "08080808-1111-2222-3333-444444444444")!,
        entryID: UUID(uuidString: "09090909-1111-2222-3333-444444444444")!,
        scope: .workspacePersona,
        title: "Workspace persona habit",
        body: "Scoped to the workspace persona instance.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_533)
      )
      let personaGlobalBundle = approvedMemoryRecordBundle(
        room: room,
        candidateID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        reviewID: UUID(uuidString: "12121212-2222-3333-4444-555555555555")!,
        entryID: UUID(uuidString: "13131313-2222-3333-4444-555555555555")!,
        profileID: UUID(uuidString: "14141414-2222-3333-4444-555555555555")!,
        scope: .personaGlobal,
        title: "Persona global craft",
        body: "Scoped to the shared Samwise template.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_534),
        includePersonaGlobalProfile: true
      )
      let organizationBundle = approvedMemoryRecordBundle(
        room: room,
        candidateID: UUID(uuidString: "15151515-2222-3333-4444-555555555555")!,
        reviewID: UUID(uuidString: "16161616-2222-3333-4444-555555555555")!,
        entryID: UUID(uuidString: "17171717-2222-3333-4444-555555555555")!,
        scope: .organization,
        title: "Organization memory",
        body: "Default-off organization memory should stay out of trace.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_535)
      )

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      for bundle in [
        workspaceBundle,
        workspaceWithoutLineageBundle,
        workspacePersonaBundle,
        personaGlobalBundle,
        organizationBundle,
      ] {
        try await store.recordApprovedMemory(bundle)
      }

      let collaboratorService = OrbitPhase1CollaboratorResponseService(
        runtimeStore: store,
        now: { Date(timeIntervalSince1970: 1_742_342_540) },
        makeMessageID: { UUID(uuidString: "18181818-2222-3333-4444-555555555555")! },
        makeActivationID: { activationID },
        makeAgentRunID: { agentRunID },
        makePostEventID: { UUID(uuidString: "19191919-2222-3333-4444-555555555555")! }
      )

      _ = try await collaboratorService.appendCollaboratorResponse(
        OrbitPhase1AppendCollaboratorResponseRequest(
          workspaceSlug: room.workspace.slug,
          channelSlug: room.channel.slug,
          workspacePersonaID: workspacePersona.id,
          initiatedByParticipantID: "aj",
          triggerMessageID: room.seedMessages[0].id,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: workspacePersona.id.uuidString,
          responseMode: .directAddress,
          body: "Trace the approved memory influence.",
          contract: OrbitPhase1ResolvedContractPayload(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: "participantDefault",
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            stopPointIDs: ["Pause for AJ review before execution handoff."],
            reviewGateIDs: ["intent:partner-sync-review"],
            memoryScopeIDs: ["workspace", "workspace_persona", "persona_global"]
          )
        )
      )

      let trace = try await store.loadActivationTrace(activationID: activationID)
      let contractSnapshot = try #require(trace?.contractSnapshot)
      let memory = try #require(trace?.memory)

      #expect(trace?.activation.id == activationID)
      #expect(trace?.agentRuns.map(\.id) == [agentRunID])
      #expect(contractSnapshot.directiveID == "maintain-partner-sync-and-handoffs")
      #expect(contractSnapshot.stopPointIDs == ["Pause for AJ review before execution handoff."])
      #expect(contractSnapshot.memoryScopeIDs == ["workspace", "workspace_persona", "persona_global"])
      #expect(memory.map(\.entry.id) == [
        workspaceBundle.entry.id,
        workspaceWithoutLineageBundle.entry.id,
        workspacePersonaBundle.entry.id,
        personaGlobalBundle.entry.id,
      ])
      #expect(memory.map(\.source.sourceOrder) == [0, 1, 2, 3])
      #expect(memory.map(\.source.retrievalReason) == [
        "workspace-scope-match",
        "workspace-scope-match",
        "workspace-persona-scope-match",
        "persona-template-match",
      ])
      #expect(memory.map(\.sourceCandidate?.id) == [
        workspaceBundle.candidate.id,
        nil,
        workspacePersonaBundle.candidate.id,
        personaGlobalBundle.candidate.id,
      ])
      #expect(memory.contains { $0.entry.id == organizationBundle.entry.id } == false)
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
      #expect(loadedSnapshot?.structuredAttachments.map(\.structuredObjectID) == [
        room.notes[0].id,
        decisionID,
        referenceID,
      ])
      #expect(loadedSnapshot?.orderedStructuredObjects.map(\.id) == [
        room.notes[0].id,
        decisionID,
        referenceID,
      ])
      #expect(loadedSnapshot?.meetingOpenQuestions.map(\.id) == [openQuestionID])
      #expect(loadedEvents.contains { $0.id == postEventID && $0.category == .meetingOutputCommitted })
    } catch {
      Issue.record("Unexpected live Postgres meeting completion error: \(String(reflecting: error))")
    }
  }

  @Test
  func liveRuntimeStoreLoadsMixedStructuredAttachmentsInCanonicalOrderWhenDatabaseEnvironmentIsAvailable()
    async throws
  {
    guard let configuration = integrationConfiguration() else {
      return
    }

    do {
      let store = OrbitPostgresRuntimeStore(configuration: configuration)
      let room = sampleMixedStructuredAttachmentRoomBootstrap()

      try await store.applyPhase1Schema()
      try await store.bootstrapRoom(room)

      let loadedSnapshot = try await store.loadRoomSnapshot(
        workspaceSlug: room.workspace.slug,
        channelSlug: room.channel.slug,
        postID: room.post.id
      )

      let noteID = try #require(room.notes.first?.id)
      let decisionID = try #require(room.decisions.first?.id)
      let referenceID = try #require(room.references.first?.id)
      let artifactID = try #require(room.artifacts.first?.id)

      #expect(loadedSnapshot?.notes.map(\.id) == [noteID])
      #expect(loadedSnapshot?.decisions.map(\.id) == [decisionID])
      #expect(loadedSnapshot?.references.map(\.id) == [referenceID])
      #expect(loadedSnapshot?.artifacts.map(\.id) == [artifactID])
      #expect(loadedSnapshot?.structuredAttachments.map(\.structuredObjectID) == [
        artifactID,
        noteID,
        decisionID,
        referenceID,
      ])
      #expect(loadedSnapshot?.orderedStructuredObjects.map(\.id) == [
        artifactID,
        noteID,
        decisionID,
        referenceID,
      ])
    } catch {
      Issue.record(
        "Unexpected live Postgres mixed structured attachment error: \(String(reflecting: error))"
      )
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

  private func sampleRoomBootstrap(
    personaTemplateID: String = "samwise"
  ) -> OrbitPhase1RoomBootstrap {
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
          personaTemplateID: personaTemplateID,
          displayName: personaTemplateID == "samwise" ? "Samwise" : "ProdDoc",
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

  private func sampleApprovedMemoryRecordBundle(
    room: OrbitPhase1RoomBootstrap
  ) -> OrbitApprovedMemoryRecordBundle {
    approvedMemoryRecordBundle(
      room: room,
      candidateID: UUID(uuidString: "c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1")!,
      reviewID: UUID(uuidString: "c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2")!,
      entryID: UUID(uuidString: "c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3")!,
      profileID: UUID(uuidString: "c4c4c4c4-c4c4-c4c4-c4c4-c4c4c4c4c4c4")!,
      scope: .personaGlobal,
      title: "Samwise keeps approved memory separate",
      body: "Approved memory remains a durable runtime artifact, not an authored persona mutation.",
      createdAt: Date(timeIntervalSince1970: 1_742_342_530),
      includePersonaGlobalProfile: true
    )
  }

  private func approvedMemoryRecordBundle(
    room: OrbitPhase1RoomBootstrap,
    candidateID: UUID,
    reviewID: UUID,
    entryID: UUID,
    profileID: UUID? = nil,
    scope: OrbitMemoryScope,
    title: String,
    body: String,
    createdAt: Date,
    status: OrbitMemoryEntryStatus = .active,
    workspaceID: UUID? = nil,
    workspacePersonaID: UUID? = nil,
    personaTemplateID: String? = nil,
    includePersonaGlobalProfile: Bool = false
  ) -> OrbitApprovedMemoryRecordBundle {
    let workspacePersona = room.workspacePersonas[0]
    let candidateCreatedAt = createdAt.addingTimeInterval(-5)
    let effectiveWorkspaceID = workspaceID ?? {
      switch scope {
      case .workspace, .workspacePersona:
        return room.workspace.id
      case .personaGlobal, .organization:
        return nil
      }
    }()
    let effectiveWorkspacePersonaID = workspacePersonaID ?? {
      switch scope {
      case .workspacePersona:
        return workspacePersona.id
      case .workspace, .personaGlobal, .organization:
        return nil
      }
    }()
    let effectivePersonaTemplateID = personaTemplateID ?? {
      switch scope {
      case .personaGlobal:
        return workspacePersona.personaTemplateID
      case .workspace, .workspacePersona, .organization:
        return nil
      }
    }()

    return OrbitApprovedMemoryRecordBundle(
      candidate: OrbitMemoryCandidateRecord(
        id: candidateID,
        workspaceID: effectiveWorkspaceID,
        workspacePersonaID: effectiveWorkspacePersonaID ?? workspacePersona.id,
        personaTemplateID: effectivePersonaTemplateID ?? workspacePersona.personaTemplateID,
        sourceType: .post,
        sourceID: room.post.id.uuidString,
        proposedScope: scope,
        title: title,
        body: "Reviewed approved memory stays distinct from candidate staging.",
        confidence: 0.91,
        status: .approved,
        createdAt: candidateCreatedAt,
        reviewedAt: createdAt
      ),
      review: OrbitMemoryReviewRecord(
        id: reviewID,
        memoryCandidateID: candidateID,
        reviewerType: .operator,
        reviewerID: "aj",
        decision: .approve,
        notes: "Materialize as reviewed approved memory.",
        createdAt: createdAt
      ),
      entry: OrbitMemoryEntryRecord(
        id: entryID,
        scope: scope,
        workspaceID: effectiveWorkspaceID,
        workspacePersonaID: effectiveWorkspacePersonaID,
        personaTemplateID: effectivePersonaTemplateID,
        title: title,
        body: body,
        status: status,
        validFrom: createdAt,
        sourceMemoryCandidateID: candidateID,
        createdAt: createdAt
      ),
      personaGlobalProfile: includePersonaGlobalProfile
        ? OrbitPersonaGlobalMemoryProfileRecord(
          id: profileID ?? UUID(),
          personaTemplateID: workspacePersona.personaTemplateID,
          summary: "Curated \(workspacePersona.personaTemplateID) persona-global memory profile.",
          lastCuratedAt: createdAt,
          createdAt: createdAt
        )
        : nil
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

  private func sampleMixedStructuredAttachmentRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let bootstrap = sampleRoomBootstrap()
    let noteID = UUID()
    let decisionID = UUID()
    let referenceID = UUID()
    let artifactID = UUID()
    let baseDate = bootstrap.post.createdAt

    return OrbitPhase1RoomBootstrap(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      post: bootstrap.post,
      thread: bootstrap.thread,
      seedMessages: bootstrap.seedMessages,
      postParticipants: bootstrap.postParticipants,
      notes: [
        OrbitNoteRecord(
          id: noteID,
          postID: bootstrap.post.id,
          noteType: .brief,
          body: "Narrative context for the mixed attachment slice.",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: baseDate
        )
      ],
      decisions: [
        OrbitDecisionRecord(
          id: decisionID,
          postID: bootstrap.post.id,
          title: "Adopt structured attachment ordering",
          body: "Read mixed structured objects through one canonical ordered lane.",
          decisionState: .adopted,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: baseDate.addingTimeInterval(1)
        )
      ],
      references: [
        OrbitReferenceRecord(
          id: referenceID,
          postID: bootstrap.post.id,
          referenceType: .doc,
          target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md",
          title: "Runtime model RFC",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: baseDate.addingTimeInterval(2)
        )
      ],
      artifacts: [
        OrbitArtifactRecord(
          id: artifactID,
          postID: bootstrap.post.id,
          artifactType: .report,
          storageRef: "reports/m6-p2-slice.md",
          title: "M6 P2 Slice",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: baseDate.addingTimeInterval(3)
        )
      ],
      structuredAttachments: [
        OrbitStructuredAttachmentRecord(
          originPostID: bootstrap.post.id,
          structuredObjectType: .artifact,
          structuredObjectID: artifactID,
          attachmentOrdinal: 0,
          attachedAt: baseDate.addingTimeInterval(10)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: bootstrap.post.id,
          structuredObjectType: .note,
          structuredObjectID: noteID,
          attachmentOrdinal: 1,
          attachedAt: baseDate.addingTimeInterval(11)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: bootstrap.post.id,
          structuredObjectType: .decision,
          structuredObjectID: decisionID,
          attachmentOrdinal: 2,
          attachedAt: baseDate.addingTimeInterval(12)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: bootstrap.post.id,
          structuredObjectType: .reference,
          structuredObjectID: referenceID,
          attachmentOrdinal: 3,
          attachedAt: baseDate.addingTimeInterval(13)
        ),
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
