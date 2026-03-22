import Foundation
import PostgresNIO
import Testing

@testable import OrbitServerRuntime

actor RecordingRepositoryExecutor: OrbitPostgresStatementExecutor {
  private(set) var recordedQueries = [PostgresQuery]()

  func execute(query: PostgresQuery) async throws {
    recordedQueries.append(query)
  }

  func queries() -> [PostgresQuery] {
    recordedQueries
  }
}

actor FailingRepositoryExecutor: OrbitPostgresStatementExecutor {
  private let failureIndex: Int
  private(set) var recordedQueries = [PostgresQuery]()

  init(
    failureIndex: Int
  ) {
    self.failureIndex = failureIndex
  }

  func execute(query: PostgresQuery) async throws {
    recordedQueries.append(query)

    if recordedQueries.count == failureIndex {
      throw TestFailure.simulatedFailure
    }
  }

  func queries() -> [PostgresQuery] {
    recordedQueries
  }
}

enum TestFailure: Error {
  case simulatedFailure
}

struct Phase1RuntimeRepositoryTests {
  private let repository = OrbitPhase1RuntimeRepository()
  private let referenceDate = Date(timeIntervalSince1970: 1_742_342_400)

  @Test
  func bootstrapRoomExecutesCanonicalInsertsInsideTransaction() async throws {
    let executor = RecordingRepositoryExecutor()

    try await repository.bootstrapRoom(sampleRoomBootstrap(), using: executor)

    let queries = await executor.queries().map { $0.sql }

    #expect(queries.first == "BEGIN")
    #expect(queries.last == "COMMIT")
    #expect(queries.contains(where: { $0.contains("INSERT INTO workspace") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO channel") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO workspace_persona") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO team") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO squad") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO workspace_persona_membership") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO post") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO thread") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO realtime_event") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_participant") }))
    #expect(queries.filter { $0.contains("INSERT INTO message") }.count == 2)
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_event") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO persona_activation") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO agent_run") }))
  }

  @Test
  func bootstrapMeetingRoomExecutesMeetingRuntimeInsertsInsideTransaction() async throws {
    let executor = RecordingRepositoryExecutor()

    try await repository.bootstrapRoom(sampleMeetingRoomBootstrap(), using: executor)

    let queries = await executor.queries().map { $0.sql }

    #expect(queries.contains(where: { $0.contains("INSERT INTO meeting_state") }))
    #expect(queries.filter { $0.contains("INSERT INTO meeting_member") }.count == 2)
  }

  @Test
  func promoteMeetingRoomExecutesOriginEvidenceAndMeetingBootstrapInsideTransaction() async throws {
    let executor = RecordingRepositoryExecutor()

    try await repository.promoteMeetingRoom(
      originPostEvent: sampleOriginPromotionAttemptPostEvent(),
      originRealtimeEvents: sampleOriginPromotionAttemptRealtimeEvents(),
      room: samplePromotedMeetingRoomBootstrap(),
      using: executor
    )

    let queries = await executor.queries().map { $0.sql }

    #expect(queries.first == "BEGIN")
    #expect(queries.last == "COMMIT")
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_event") }))
    #expect(queries.filter { $0.contains("INSERT INTO post_event") }.count >= 2)
    #expect(queries.filter { $0.contains("INSERT INTO realtime_event") }.count >= 2)
    #expect(queries.contains(where: { $0.contains("INSERT INTO post") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_link") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO meeting_state") }))
    #expect(queries.filter { $0.contains("INSERT INTO meeting_member") }.count == 2)
  }

  @Test
  func bootstrapRoomRollsBackWhenAnInsertFails() async {
    let executor = FailingRepositoryExecutor(failureIndex: 4)

    do {
      try await repository.bootstrapRoom(sampleRoomBootstrap(), using: executor)
      Issue.record("Expected bootstrap failure")
    } catch TestFailure.simulatedFailure {
      let queries = await executor.queries().map { $0.sql }

      #expect(queries.first == "BEGIN")
      #expect(queries.last == "ROLLBACK")
      #expect(queries.contains(where: { $0.contains("INSERT INTO workspace_persona") }))
      #expect(queries.contains(where: { $0.contains("COMMIT") }) == false)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func roomSnapshotQueryReadsCanonicalWorkspaceChannelPostAndThreadState() {
    let query = repository.selectRoomSnapshotQuery(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )

    #expect(query.sql.contains("FROM workspace"))
    #expect(query.sql.contains("workspace.slug AS workspace_slug"))
    #expect(query.sql.contains("JOIN channel ON channel.workspace_id = workspace.id"))
    #expect(query.sql.contains("JOIN post ON post.channel_id = channel.id"))
    #expect(query.sql.contains("JOIN thread ON thread.post_id = post.id"))
    #expect(query.sql.contains("ORDER BY post.created_at ASC, thread.created_at ASC"))
    #expect(query.sql.contains("LIMIT 1"))
    #expect(query.binds.count == 2)
  }

  @Test
  func roomSnapshotQueryCanTargetAnExplicitPostID() {
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let query = repository.selectRoomSnapshotQuery(
      workspaceSlug: "orbit",
      channelSlug: "command-center",
      postID: postID
    )

    #expect(query.sql.contains("WHERE workspace.slug = $1"))
    #expect(query.sql.contains("AND channel.slug = $2"))
    #expect(query.sql.contains("AND post.id = $3"))
    #expect(query.sql.contains("ORDER BY thread.created_at ASC"))
    #expect(query.sql.contains("LIMIT 1"))
    #expect(query.binds.count == 3)
  }

  @Test
  func meetingRoomContextQueryReadsWorkspaceAndChannelWithoutPostDependency() {
    let query = repository.selectMeetingRoomContextQuery(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )

    #expect(query.sql.contains("FROM workspace"))
    #expect(query.sql.contains("JOIN channel ON channel.workspace_id = workspace.id"))
    #expect(query.sql.contains("JOIN post") == false)
    #expect(query.sql.contains("JOIN thread") == false)
    #expect(query.sql.contains("WHERE workspace.slug = $1"))
    #expect(query.sql.contains("AND channel.slug = $2"))
    #expect(query.sql.contains("LIMIT 1"))
    #expect(query.binds.count == 2)
  }

  @Test
  func threadMessagesQueryPreservesReplayOrder() {
    let query = repository.selectThreadMessagesQuery(threadID: UUID())

    #expect(query.sql.contains("FROM message"))
    #expect(query.sql.contains("WHERE thread_id = $1"))
    #expect(query.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(query.binds.count == 1)
  }

  @Test
  func participantAndEventQueriesPreserveReplayOrder() {
    let participantQuery = repository.selectPostParticipantsQuery(postID: UUID())
    let postLinkQuery = repository.selectPostLinksQuery(postID: UUID())
    let meetingStateQuery = repository.selectMeetingStateQuery(postID: UUID())
    let meetingMemberQuery = repository.selectMeetingMembersQuery(meetingPostID: UUID())
    let eventQuery = repository.selectPostEventsQuery(postID: UUID())
    let workspacePersonaQuery = repository.selectWorkspacePersonasQuery(workspaceID: UUID())
    let teamQuery = repository.selectTeamsQuery(workspaceID: UUID())
    let squadQuery = repository.selectSquadsQuery(workspaceID: UUID())
    let membershipQuery = repository.selectWorkspacePersonaMembershipsQuery(workspaceID: UUID())
    let realtimeEventQuery = repository.selectRealtimeEventsQuery(
      workspaceID: UUID(),
      after: nil
    )

    #expect(workspacePersonaQuery.sql.contains("FROM workspace_persona"))
    #expect(workspacePersonaQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(workspacePersonaQuery.binds.count == 1)

    #expect(teamQuery.sql.contains("FROM team"))
    #expect(teamQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(teamQuery.binds.count == 1)

    #expect(squadQuery.sql.contains("FROM squad"))
    #expect(squadQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(squadQuery.binds.count == 1)

    #expect(membershipQuery.sql.contains("FROM workspace_persona_membership"))
    #expect(membershipQuery.sql.contains("JOIN workspace_persona"))
    #expect(membershipQuery.sql.contains("ORDER BY workspace_persona_membership.created_at ASC, workspace_persona_membership.id ASC"))
    #expect(membershipQuery.binds.count == 1)

    #expect(participantQuery.sql.contains("FROM post_participant"))
    #expect(participantQuery.sql.contains("ORDER BY joined_at ASC, id ASC"))
    #expect(participantQuery.binds.count == 1)

    #expect(postLinkQuery.sql.contains("FROM post_link"))
    #expect(postLinkQuery.sql.contains("WHERE from_post_id = $1"))
    #expect(postLinkQuery.sql.contains("OR to_post_id = $2"))
    #expect(postLinkQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(postLinkQuery.binds.count == 2)

    #expect(meetingStateQuery.sql.contains("FROM meeting_state"))
    #expect(meetingStateQuery.sql.contains("WHERE post_id = $1"))
    #expect(meetingStateQuery.binds.count == 1)

    #expect(meetingMemberQuery.sql.contains("FROM meeting_member"))
    #expect(meetingMemberQuery.sql.contains("WHERE meeting_post_id = $1"))
    #expect(meetingMemberQuery.sql.contains("ORDER BY joined_at ASC, id ASC"))
    #expect(meetingMemberQuery.binds.count == 1)

    #expect(eventQuery.sql.contains("FROM post_event"))
    #expect(eventQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(eventQuery.binds.count == 1)

    #expect(realtimeEventQuery.sql.contains("FROM realtime_event"))
    #expect(realtimeEventQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(realtimeEventQuery.binds.count == 1)
  }

  @Test
  func realtimeEventQueryCanTargetAnExplicitPostID() {
    let postID = UUID(uuidString: "34343434-3434-3434-3434-343434343434")!
    let cursor = OrbitPhase1ReplayCursor(
      workspaceID: UUID(uuidString: "45454545-4545-4545-4545-454545454545")!,
      lastEventID: UUID(uuidString: "56565656-5656-5656-5656-565656565656")!,
      lastEventCreatedAt: referenceDate
    )
    let query = repository.selectRealtimeEventsQuery(
      workspaceID: cursor.workspaceID,
      postID: postID,
      after: cursor
    )

    #expect(query.sql.contains("FROM realtime_event"))
    #expect(query.sql.contains("WHERE workspace_id = $1"))
    #expect(query.sql.contains("AND post_id = $2"))
    #expect(query.sql.contains("created_at > $3"))
    #expect(query.sql.contains("id > $5"))
    #expect(query.binds.count == 5)
  }

  @Test
  func teamMembershipUpsertGuardsAgainstDuplicateNaturalKeys() {
    let membership = sampleRoomBootstrap().workspacePersonaMemberships[0]
    let query = repository.upsertWorkspacePersonaMembershipQuery(membership)

    #expect(query.sql.contains("WHERE NOT EXISTS"))
    #expect(query.sql.contains("SELECT 1"))
    #expect(query.sql.contains("FROM workspace_persona_membership"))
    #expect(query.sql.contains("id <>"))
    #expect(query.sql.contains("workspace_persona_id ="))
    #expect(query.sql.contains("team_id ="))
    #expect(query.sql.contains("ON CONFLICT (id) DO UPDATE"))
  }

  @Test
  func squadMembershipUpsertGuardsAgainstDuplicateNaturalKeys() {
    let membership = sampleRoomBootstrap().workspacePersonaMemberships[1]
    let query = repository.upsertWorkspacePersonaMembershipQuery(membership)

    #expect(query.sql.contains("WHERE NOT EXISTS"))
    #expect(query.sql.contains("SELECT 1"))
    #expect(query.sql.contains("FROM workspace_persona_membership"))
    #expect(query.sql.contains("id <>"))
    #expect(query.sql.contains("workspace_persona_id ="))
    #expect(query.sql.contains("squad_id ="))
    #expect(query.sql.contains("ON CONFLICT (id) DO UPDATE"))
  }

  @Test
  func malformedMembershipUpsertUsesDirectInsertPathToPreserveDatabaseValidation() {
    let membership = OrbitWorkspacePersonaMembershipRecord(
      id: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
      workspacePersonaID: sampleRoomBootstrap().workspacePersonaMemberships[0].workspacePersonaID,
      teamID: nil,
      squadID: nil,
      roleInGroup: "reviewer",
      createdAt: referenceDate
    )
    let query = repository.upsertWorkspacePersonaMembershipQuery(membership)

    #expect(query.sql.contains("INSERT INTO workspace_persona_membership"))
    #expect(query.sql.contains("VALUES ("))
    #expect(query.sql.contains("ON CONFLICT (id) DO UPDATE"))
    #expect(query.sql.contains("WHERE NOT EXISTS") == false)
    #expect(query.sql.contains("WHERE 1 = 0") == false)
  }

  @Test
  func activationAndRunQueryLinksActivationTraceToExecutionState() {
    let query = repository.selectPostActivationsAndRunsQuery(originPostID: UUID())

    #expect(query.sql.contains("FROM persona_activation"))
    #expect(query.sql.contains("LEFT JOIN agent_run ON agent_run.persona_activation_id = persona_activation.id"))
    #expect(query.sql.contains("ORDER BY persona_activation.created_at ASC"))
    #expect(query.binds.count == 1)
  }

  @Test
  func appendMessageWrapsInsertAndThreadTouchInsideTransaction() async throws {
    let executor = RecordingRepositoryExecutor()
    let message = sampleRoomBootstrap().seedMessages[1]
    let meetingState = OrbitMeetingStateRecord(
      postID: sampleRoomBootstrap().post.id,
      meetingType: .team,
      status: .active,
      startedByParticipantType: .user,
      startedByParticipantID: "aj",
      startedAt: referenceDate
    )

    try await repository.appendMessage(
      workspaceID: sampleRoomBootstrap().workspace.id,
      message,
      realtimeEvents: [
        OrbitRealtimeEventRecord(
          id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
          workspaceID: sampleRoomBootstrap().workspace.id,
          postID: sampleRoomBootstrap().post.id,
          threadID: sampleRoomBootstrap().thread.id,
          category: .messageCreated,
          payloadJSON: "{\"message_id\":\"\(message.id.uuidString)\"}",
          createdAt: referenceDate.addingTimeInterval(120)
        )
      ],
      meetingState: meetingState,
      threadLastActivityAt: referenceDate.addingTimeInterval(120),
      using: executor
    )

    let queries = await executor.queries().map { $0.sql }

    #expect(queries.first == "BEGIN")
    #expect(queries.last == "COMMIT")
    #expect(queries.contains(where: { $0.contains("INSERT INTO message") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO realtime_event") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO meeting_state") }))
    #expect(queries.contains(where: { $0.contains("UPDATE thread") }))
  }

  @Test
  func meetingRuntimeUpsertsUseStableConflictKeys() {
    let room = sampleMeetingRoomBootstrap()
    let meetingState = room.meetingState!
    let meetingMember = room.meetingMembers[0]

    let meetingStateQuery = repository.upsertMeetingStateQuery(meetingState)
    let meetingMemberQuery = repository.upsertMeetingMemberQuery(meetingMember)

    #expect(meetingStateQuery.sql.contains("INSERT INTO meeting_state"))
    #expect(meetingStateQuery.sql.contains("ON CONFLICT (post_id) DO UPDATE"))
    #expect(meetingMemberQuery.sql.contains("INSERT INTO meeting_member"))
    #expect(meetingMemberQuery.sql.contains("ON CONFLICT (meeting_post_id, post_participant_id) DO UPDATE"))
  }

  private func sampleRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let samwiseWorkspacePersonaID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    let prodDocWorkspacePersonaID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    let foundingGroupTeamID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let feedbackSquadID = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!
    let activationID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    let runID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    return OrbitPhase1RoomBootstrap(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: referenceDate
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: referenceDate
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: samwiseWorkspacePersonaID,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: referenceDate
        ),
        OrbitWorkspacePersonaRecord(
          id: prodDocWorkspacePersonaID,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: referenceDate
        ),
      ],
      teams: [
        OrbitTeamRecord(
          id: foundingGroupTeamID,
          workspaceID: workspaceID,
          slug: "founding-group",
          name: "Founding Group",
          purpose: "Seeded first team target.",
          createdAt: referenceDate
        )
      ],
      squads: [
        OrbitSquadRecord(
          id: feedbackSquadID,
          workspaceID: workspaceID,
          teamID: foundingGroupTeamID,
          slug: "command-center-feedback-squad",
          name: "Command Center Feedback Squad",
          purpose: "Focused feedback lane.",
          createdAt: referenceDate.addingTimeInterval(1)
        )
      ],
      workspacePersonaMemberships: [
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
          workspacePersonaID: samwiseWorkspacePersonaID,
          teamID: foundingGroupTeamID,
          roleInGroup: "trusted-partner",
          createdAt: referenceDate.addingTimeInterval(2)
        ),
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
          workspacePersonaID: prodDocWorkspacePersonaID,
          squadID: feedbackSquadID,
          roleInGroup: "reviewer",
          createdAt: referenceDate.addingTimeInterval(3)
        ),
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit checkpoint room",
        status: .active,
        createdAt: referenceDate
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: referenceDate,
        createdAt: referenceDate
      ),
      seedMessages: [
        OrbitMessageRecord(
          id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit is ready for canonical truth.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: referenceDate,
          updatedAt: referenceDate
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-samwise",
          body: "Server cutover should preserve this room meaning.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: referenceDate.addingTimeInterval(60),
          updatedAt: referenceDate.addingTimeInterval(60)
        ),
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          postID: postID,
          participantType: .user,
          participantID: "aj",
          joinedAt: referenceDate,
          participationMode: .active
        ),
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: samwiseWorkspacePersonaID.uuidString,
          joinedAt: referenceDate,
          participationMode: .active
        ),
      ],
      postEvents: [
        OrbitPostEventRecord(
          id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
          postID: postID,
          threadID: threadID,
          eventType: "activation.resolved",
          payloadJSON: "{\"response_mode\":\"direct-address\"}",
          createdAt: referenceDate.addingTimeInterval(61)
        ),
      ],
      personaActivations: [
        OrbitPersonaActivationRecord(
          id: activationID,
          initiatedByParticipantType: .user,
          initiatedByParticipantID: "aj",
          workspaceID: workspaceID,
          channelID: channelID,
          originPostID: postID,
          originThreadID: threadID,
          triggerMessageID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          addressedTargetKind: .collaborator,
          addressedTargetReferenceID: samwiseWorkspacePersonaID.uuidString,
          resolvedWorkspacePersonaInstanceID: samwiseWorkspacePersonaID,
          responseMode: .directAddress,
          createdAt: referenceDate.addingTimeInterval(61)
        ),
      ],
      agentRuns: [
        OrbitAgentRunRecord(
          id: runID,
          personaActivationID: activationID,
          runnerKind: "local-bridge",
          status: .completed,
          startedAt: referenceDate.addingTimeInterval(61),
          completedAt: referenceDate.addingTimeInterval(62)
        ),
      ]
    )
  }

  private func sampleMeetingRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let bootstrap = sampleRoomBootstrap()
    let participantIDs = bootstrap.postParticipants.map(\.id)

    return OrbitPhase1RoomBootstrap(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      teams: bootstrap.teams,
      squads: bootstrap.squads,
      workspacePersonaMemberships: bootstrap.workspacePersonaMemberships,
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
      realtimeEvents: bootstrap.realtimeEvents,
      postParticipants: bootstrap.postParticipants,
      meetingState: OrbitMeetingStateRecord(
        postID: bootstrap.post.id,
        meetingType: .team,
        status: .active,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: referenceDate
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "dededede-dede-dede-dede-dededededede")!,
          meetingPostID: bootstrap.post.id,
          postParticipantID: participantIDs[0],
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: bootstrap.postParticipants[0].joinedAt
        ),
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "efefefef-efef-efef-efef-efefefefefef")!,
          meetingPostID: bootstrap.post.id,
          postParticipantID: participantIDs[1],
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: bootstrap.postParticipants[1].joinedAt
        ),
      ],
      postEvents: bootstrap.postEvents,
      personaActivations: bootstrap.personaActivations,
      agentRuns: bootstrap.agentRuns
    )
  }

  private func samplePromotedMeetingRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let meetingRoom = sampleMeetingRoomBootstrap()
    let originRoom = sampleRoomBootstrap()
    let promotedPostID = UUID(uuidString: "02020202-0202-0202-0202-020202020202")!
    let promotedThreadID = UUID(uuidString: "03030303-0303-0303-0303-030303030303")!
    let promotedParticipants = meetingRoom.postParticipants.map { participant in
      OrbitPostParticipantRecord(
        id: participant.id,
        postID: promotedPostID,
        participantType: participant.participantType,
        participantID: participant.participantID,
        joinedAt: participant.joinedAt,
        leftAt: participant.leftAt,
        participationMode: participant.participationMode
      )
    }

    return OrbitPhase1RoomBootstrap(
      workspace: meetingRoom.workspace,
      channel: meetingRoom.channel,
      workspacePersonas: meetingRoom.workspacePersonas,
      teams: meetingRoom.teams,
      squads: meetingRoom.squads,
      workspacePersonaMemberships: meetingRoom.workspacePersonaMemberships,
      post: OrbitPostRecord(
        id: promotedPostID,
        workspaceID: meetingRoom.post.workspaceID,
        channelID: meetingRoom.post.channelID,
        postType: .meeting,
        createdByParticipantType: meetingRoom.post.createdByParticipantType,
        createdByParticipantID: meetingRoom.post.createdByParticipantID,
        title: meetingRoom.post.title,
        status: meetingRoom.post.status,
        createdAt: meetingRoom.post.createdAt.addingTimeInterval(90),
        archivedAt: meetingRoom.post.archivedAt
      ),
      thread: OrbitThreadRecord(
        id: promotedThreadID,
        postID: promotedPostID,
        status: meetingRoom.thread.status,
        lastActivityAt: meetingRoom.thread.lastActivityAt.addingTimeInterval(90),
        createdAt: meetingRoom.thread.createdAt.addingTimeInterval(90),
        closedAt: meetingRoom.thread.closedAt
      ),
      seedMessages: meetingRoom.seedMessages.map { message in
        OrbitMessageRecord(
          id: message.id,
          postID: promotedPostID,
          threadID: promotedThreadID,
          authorType: message.authorType,
          authorID: message.authorID,
          replyToMessageID: message.replyToMessageID,
          body: message.body,
          messageFormat: message.messageFormat,
          state: message.state,
          createdAt: message.createdAt.addingTimeInterval(90),
          updatedAt: message.updatedAt.addingTimeInterval(90)
        )
      },
      realtimeEvents: [],
      postParticipants: promotedParticipants,
      postLinks: [
        OrbitPostLinkRecord(
          id: UUID(uuidString: "01010101-0101-0101-0101-010101010101")!,
          fromPostID: originRoom.post.id,
          toPostID: promotedPostID,
          linkType: .promotion,
          createdAt: referenceDate.addingTimeInterval(89)
        )
      ],
      meetingState: OrbitMeetingStateRecord(
        postID: promotedPostID,
        meetingType: .team,
        status: .active,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: referenceDate.addingTimeInterval(90)
      ),
      meetingMembers: promotedParticipants.map { participant in
        OrbitMeetingMemberRecord(
          id: participant.id,
          meetingPostID: promotedPostID,
          postParticipantID: participant.id,
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: participant.joinedAt
        )
      },
      postEvents: [
        OrbitPostEventRecord(
          id: UUID(uuidString: "04040404-0404-0404-0404-040404040404")!,
          postID: promotedPostID,
          threadID: promotedThreadID,
          eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
          payloadJSON: "{\"response_mode\":\"direct-address\"}",
          createdAt: referenceDate.addingTimeInterval(91)
        )
      ],
      personaActivations: [],
      agentRuns: []
    )
  }

  private func sampleOriginPromotionAttemptPostEvent() -> OrbitPostEventRecord {
    let room = sampleRoomBootstrap()

    return OrbitPostEventRecord(
      id: UUID(uuidString: "f1f1f1f1-f1f1-f1f1-f1f1-f1f1f1f1f1f1")!,
      postID: room.post.id,
      threadID: room.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
      payloadJSON: "{\"title\":\"Founding Group Meeting\"}",
      createdAt: referenceDate.addingTimeInterval(90)
    )
  }

  private func sampleOriginPromotionAttemptRealtimeEvents() -> [OrbitRealtimeEventRecord] {
    let room = sampleRoomBootstrap()
    let postEvent = sampleOriginPromotionAttemptPostEvent()

    return [
      OrbitRealtimeEventRecord(
        id: UUID(uuidString: "f2f2f2f2-f2f2-f2f2-f2f2-f2f2f2f2f2f2")!,
        workspaceID: room.workspace.id,
        postID: room.post.id,
        threadID: room.thread.id,
        category: .meetingPromotionAttempted,
        payloadJSON: postEvent.payloadJSON,
        createdAt: postEvent.createdAt
      )
    ]
  }
}
