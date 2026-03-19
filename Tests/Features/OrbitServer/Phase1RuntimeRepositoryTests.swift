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
    #expect(queries.contains(where: { $0.contains("INSERT INTO post") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO thread") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_participant") }))
    #expect(queries.filter { $0.contains("INSERT INTO message") }.count == 2)
    #expect(queries.contains(where: { $0.contains("INSERT INTO post_event") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO persona_activation") }))
    #expect(queries.contains(where: { $0.contains("INSERT INTO agent_run") }))
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
    let eventQuery = repository.selectPostEventsQuery(postID: UUID())
    let workspacePersonaQuery = repository.selectWorkspacePersonasQuery(workspaceID: UUID())

    #expect(workspacePersonaQuery.sql.contains("FROM workspace_persona"))
    #expect(workspacePersonaQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(workspacePersonaQuery.binds.count == 1)

    #expect(participantQuery.sql.contains("FROM post_participant"))
    #expect(participantQuery.sql.contains("ORDER BY joined_at ASC, id ASC"))
    #expect(participantQuery.binds.count == 1)

    #expect(eventQuery.sql.contains("FROM post_event"))
    #expect(eventQuery.sql.contains("ORDER BY created_at ASC, id ASC"))
    #expect(eventQuery.binds.count == 1)
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

    try await repository.appendMessage(
      message,
      threadLastActivityAt: referenceDate.addingTimeInterval(120),
      using: executor
    )

    let queries = await executor.queries().map { $0.sql }

    #expect(queries.first == "BEGIN")
    #expect(queries.last == "COMMIT")
    #expect(queries.contains(where: { $0.contains("INSERT INTO message") }))
    #expect(queries.contains(where: { $0.contains("UPDATE thread") }))
  }

  private func sampleRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let samwiseWorkspacePersonaID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    let prodDocWorkspacePersonaID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
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
}
