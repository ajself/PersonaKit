import Foundation
import PostgresNIO

public struct OrbitPostgresConfiguration: Equatable, Sendable {
  public let host: String
  public let port: Int
  public let username: String
  public let password: String
  public let database: String
  public let tls: OrbitPostgresTLSMode

  public init(
    host: String,
    port: Int = 5432,
    username: String,
    password: String,
    database: String,
    tls: OrbitPostgresTLSMode = .disable
  ) {
    self.host = host
    self.port = port
    self.username = username
    self.password = password
    self.database = database
    self.tls = tls
  }

  var postgresClientConfiguration: PostgresClient.Configuration {
    PostgresClient.Configuration(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
      tls: tls.postgresTLS
    )
  }
}

public enum OrbitPostgresTLSMode: Equatable, Sendable {
  case disable

  var postgresTLS: PostgresClient.Configuration.TLS {
    switch self {
    case .disable:
      return .disable
    }
  }
}

public protocol OrbitPostgresStatementExecutor: Sendable {
  func execute(query: PostgresQuery) async throws
}

public struct OrbitPostgresClientExecutor: OrbitPostgresStatementExecutor {
  private let client: PostgresClient

  public init(
    client: PostgresClient
  ) {
    self.client = client
  }

  public func execute(query: PostgresQuery) async throws {
    _ = try await client.query(query)
  }
}

public struct OrbitPhase1RuntimeMigrator: Sendable {
  public let statements: [OrbitPhase1SchemaStatement]

  public init(
    statements: [OrbitPhase1SchemaStatement] = OrbitPhase1RuntimeSchema.statements
  ) {
    self.statements = statements
  }

  public func apply(
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    for statement in statements {
      try await executor.execute(query: PostgresQuery(unsafeSQL: statement.sql))
    }
  }
}

public struct OrbitPostgresRuntimeStore: Sendable {
  public let configuration: OrbitPostgresConfiguration

  public init(
    configuration: OrbitPostgresConfiguration
  ) {
    self.configuration = configuration
  }

  public func applyPhase1Schema(
    migrator: OrbitPhase1RuntimeMigrator = OrbitPhase1RuntimeMigrator()
  ) async throws {
    try await withClient { client in
      try await migrator.apply(using: OrbitPostgresClientExecutor(client: client))
    }
  }

  public func bootstrapRoom(
    _ room: OrbitPhase1RoomBootstrap,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws {
    try await withClient { client in
      try await repository.bootstrapRoom(room, using: OrbitPostgresClientExecutor(client: client))
    }
  }

  public func appendMessage(
    workspaceID: UUID,
    _ message: OrbitMessageRecord,
    realtimeEvents: [OrbitRealtimeEventRecord] = [],
    threadLastActivityAt: Date,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws {
    try await withClient { client in
      try await repository.appendMessage(
        workspaceID: workspaceID,
        message,
        realtimeEvents: realtimeEvents,
        threadLastActivityAt: threadLastActivityAt,
        using: OrbitPostgresClientExecutor(client: client)
      )
    }
  }

  public func appendCollaboratorResponse(
    workspaceID: UUID,
    _ message: OrbitMessageRecord,
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    threadLastActivityAt: Date,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws {
    try await withClient { client in
      try await repository.appendCollaboratorResponse(
        workspaceID: workspaceID,
        message,
        activation: activation,
        agentRun: agentRun,
        postEvent: postEvent,
        realtimeEvents: realtimeEvents,
        threadLastActivityAt: threadLastActivityAt,
        using: OrbitPostgresClientExecutor(client: client)
      )
    }
  }

  public func appendActivationFailure(
    workspaceID: UUID,
    _ systemMessage: OrbitMessageRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    threadLastActivityAt: Date,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws {
    try await withClient { client in
      try await repository.appendActivationFailure(
        workspaceID: workspaceID,
        systemMessage,
        postEvent: postEvent,
        realtimeEvents: realtimeEvents,
        threadLastActivityAt: threadLastActivityAt,
        using: OrbitPostgresClientExecutor(client: client)
      )
    }
  }

  public func loadRoomSnapshot(
    workspaceSlug: String,
    channelSlug: String,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws -> OrbitPhase1RoomSnapshot? {
    try await withClient { client in
      let snapshotRows = try await client.query(
        repository.selectRoomSnapshotQuery(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug
        )
      ).collect()

      guard let snapshotRow = snapshotRows.first else {
        return nil
      }

      let randomAccessRow = snapshotRow.makeRandomAccess()
      let workspace = try decodeWorkspace(from: randomAccessRow)
      let channel = try decodeChannel(from: randomAccessRow)
      let post = try decodePost(from: randomAccessRow)
      let thread = try decodeThread(from: randomAccessRow)

      let workspacePersonaRows = try await client.query(
        repository.selectWorkspacePersonasQuery(workspaceID: workspace.id)
      )

      var workspacePersonas = [OrbitWorkspacePersonaRecord]()
      for try await workspacePersonaRow in workspacePersonaRows {
        workspacePersonas.append(
          try decodeWorkspacePersona(from: workspacePersonaRow.makeRandomAccess())
        )
      }

      let teamRows = try await client.query(
        repository.selectTeamsQuery(workspaceID: workspace.id)
      )

      var teams = [OrbitTeamRecord]()
      for try await teamRow in teamRows {
        teams.append(try decodeTeam(from: teamRow.makeRandomAccess()))
      }

      let squadRows = try await client.query(
        repository.selectSquadsQuery(workspaceID: workspace.id)
      )

      var squads = [OrbitSquadRecord]()
      for try await squadRow in squadRows {
        squads.append(try decodeSquad(from: squadRow.makeRandomAccess()))
      }

      let workspacePersonaMembershipRows = try await client.query(
        repository.selectWorkspacePersonaMembershipsQuery(workspaceID: workspace.id)
      )

      var workspacePersonaMemberships = [OrbitWorkspacePersonaMembershipRecord]()
      for try await workspacePersonaMembershipRow in workspacePersonaMembershipRows {
        workspacePersonaMemberships.append(
          try decodeWorkspacePersonaMembership(
            from: workspacePersonaMembershipRow.makeRandomAccess()
          )
        )
      }

      let participantRows = try await client.query(
        repository.selectPostParticipantsQuery(postID: post.id)
      )

      var postParticipants = [OrbitPostParticipantRecord]()
      for try await participantRow in participantRows {
        postParticipants.append(
          try decodePostParticipant(from: participantRow.makeRandomAccess())
        )
      }

      let postEventRows = try await client.query(
        repository.selectPostEventsQuery(postID: post.id)
      )

      var postEvents = [OrbitPostEventRecord]()
      for try await postEventRow in postEventRows {
        postEvents.append(try decodePostEvent(from: postEventRow.makeRandomAccess()))
      }

      let activationRunRows = try await client.query(
        repository.selectPostActivationsAndRunsQuery(originPostID: post.id)
      )

      var personaActivationsByID = [UUID: OrbitPersonaActivationRecord]()
      var agentRunsByID = [UUID: OrbitAgentRunRecord]()
      for try await activationRunRow in activationRunRows {
        let randomAccessActivationRunRow = activationRunRow.makeRandomAccess()
        let activation = try decodePersonaActivation(from: randomAccessActivationRunRow)
        personaActivationsByID[activation.id] = activation

        if let agentRun = try decodeAgentRun(from: randomAccessActivationRunRow) {
          agentRunsByID[agentRun.id] = agentRun
        }
      }

      let messageRows = try await client.query(
        repository.selectThreadMessagesQuery(threadID: thread.id)
      )

      var messages = [OrbitMessageRecord]()
      for try await messageRow in messageRows {
        messages.append(try decodeMessage(from: messageRow.makeRandomAccess()))
      }

      return OrbitPhase1RoomSnapshot(
        workspace: workspace,
        channel: channel,
        workspacePersonas: workspacePersonas,
        teams: teams,
        squads: squads,
        workspacePersonaMemberships: workspacePersonaMemberships,
        post: post,
        thread: thread,
        messages: messages,
        postParticipants: postParticipants,
        postEvents: postEvents,
        personaActivations: personaActivationsByID.values.sorted { $0.createdAt < $1.createdAt },
        agentRuns: agentRunsByID.values.sorted { $0.startedAt < $1.startedAt }
      )
    }
  }

  public func loadRealtimeEvents(
    workspaceID: UUID,
    after cursor: OrbitPhase1ReplayCursor?,
    repository: OrbitPhase1RuntimeRepository = OrbitPhase1RuntimeRepository()
  ) async throws -> [OrbitPhase1RealtimeEventEnvelope] {
    try await withClient { client in
      let rows = try await client.query(
        repository.selectRealtimeEventsQuery(
          workspaceID: workspaceID,
          after: cursor
        )
      )

      var events = [OrbitPhase1RealtimeEventEnvelope]()
      for try await row in rows {
        events.append(try decodeRealtimeEvent(from: row.makeRandomAccess()))
      }

      return events
    }
  }

  private func withClient<T: Sendable>(
    _ operation: @escaping @Sendable (PostgresClient) async throws -> T
  ) async throws -> T {
    let client = PostgresClient(configuration: configuration.postgresClientConfiguration)

    return try await withThrowingTaskGroup(of: T.self) { taskGroup in
      taskGroup.addTask {
        await client.run()
        throw CancellationError()
      }

      taskGroup.addTask {
        try await operation(client)
      }

      let result = try await taskGroup.next()!
      taskGroup.cancelAll()
      return result
    }
  }

  private func decodeWorkspace(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitWorkspaceRecord {
    try OrbitWorkspaceRecord(
      id: row["workspace_id"].decode(UUID.self),
      slug: row["workspace_slug"].decode(String.self),
      name: row["workspace_name"].decode(String.self),
      status: try decodeEnum(
        OrbitWorkspaceStatus.self,
        from: row["workspace_status"],
        columnName: "workspace_status"
      ),
      createdAt: row["workspace_created_at"].decode(Date.self),
      archivedAt: row["workspace_archived_at"].decode(Optional<Date>.self)
    )
  }

  private func decodeChannel(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitChannelRecord {
    try OrbitChannelRecord(
      id: row["channel_id"].decode(UUID.self),
      workspaceID: row["workspace_id"].decode(UUID.self),
      slug: row["channel_slug"].decode(String.self),
      name: row["channel_name"].decode(String.self),
      purpose: row["channel_purpose"].decode(String.self),
      status: try decodeEnum(
        OrbitChannelStatus.self,
        from: row["channel_status"],
        columnName: "channel_status"
      ),
      createdAt: row["channel_created_at"].decode(Date.self),
      archivedAt: row["channel_archived_at"].decode(Optional<Date>.self)
    )
  }

  private func decodePost(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitPostRecord {
    try OrbitPostRecord(
      id: row["post_id"].decode(UUID.self),
      workspaceID: row["post_workspace_id"].decode(UUID.self),
      channelID: row["post_channel_id"].decode(UUID.self),
      postType: try decodeEnum(
        OrbitPostType.self,
        from: row["post_type"],
        columnName: "post_type"
      ),
      createdByParticipantType: try decodeEnum(
        OrbitParticipantAuthorType.self,
        from: row["post_created_by_participant_type"],
        columnName: "post_created_by_participant_type"
      ),
      createdByParticipantID: row["post_created_by_participant_id"].decode(String.self),
      title: row["post_title"].decode(Optional<String>.self),
      status: try decodeEnum(
        OrbitPostStatus.self,
        from: row["post_status"],
        columnName: "post_status"
      ),
      createdAt: row["post_created_at"].decode(Date.self),
      archivedAt: row["post_archived_at"].decode(Optional<Date>.self)
    )
  }

  private func decodeWorkspacePersona(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitWorkspacePersonaRecord {
    try OrbitWorkspacePersonaRecord(
      id: row["id"].decode(UUID.self),
      workspaceID: row["workspace_id"].decode(UUID.self),
      personaTemplateID: row["persona_template_id"].decode(String.self),
      displayName: row["display_name"].decode(String.self),
      defaultDirectiveOverrideID: row["default_directive_override_id"].decode(Optional<String>.self),
      status: try decodeEnum(
        OrbitWorkspacePersonaStatus.self,
        from: row["status"],
        columnName: "status"
      ),
      createdAt: row["created_at"].decode(Date.self),
      archivedAt: row["archived_at"].decode(Optional<Date>.self)
    )
  }

  private func decodeTeam(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitTeamRecord {
    try OrbitTeamRecord(
      id: row["id"].decode(UUID.self),
      workspaceID: row["workspace_id"].decode(UUID.self),
      slug: row["slug"].decode(String.self),
      name: row["name"].decode(String.self),
      purpose: row["purpose"].decode(String.self),
      createdAt: row["created_at"].decode(Date.self)
    )
  }

  private func decodeSquad(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitSquadRecord {
    try OrbitSquadRecord(
      id: row["id"].decode(UUID.self),
      workspaceID: row["workspace_id"].decode(UUID.self),
      teamID: row["team_id"].decode(Optional<UUID>.self),
      slug: row["slug"].decode(String.self),
      name: row["name"].decode(String.self),
      purpose: row["purpose"].decode(String.self),
      createdAt: row["created_at"].decode(Date.self)
    )
  }

  private func decodeWorkspacePersonaMembership(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitWorkspacePersonaMembershipRecord {
    try OrbitWorkspacePersonaMembershipRecord(
      id: row["id"].decode(UUID.self),
      workspacePersonaID: row["workspace_persona_id"].decode(UUID.self),
      teamID: row["team_id"].decode(Optional<UUID>.self),
      squadID: row["squad_id"].decode(Optional<UUID>.self),
      roleInGroup: row["role_in_group"].decode(String.self),
      createdAt: row["created_at"].decode(Date.self)
    )
  }

  private func decodeThread(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitThreadRecord {
    try OrbitThreadRecord(
      id: row["thread_id"].decode(UUID.self),
      postID: row["thread_post_id"].decode(UUID.self),
      status: try decodeEnum(
        OrbitThreadStatus.self,
        from: row["thread_status"],
        columnName: "thread_status"
      ),
      lastActivityAt: row["thread_last_activity_at"].decode(Date.self),
      createdAt: row["thread_created_at"].decode(Date.self),
      closedAt: row["thread_closed_at"].decode(Optional<Date>.self)
    )
  }

  private func decodeMessage(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitMessageRecord {
    try OrbitMessageRecord(
      id: row["id"].decode(UUID.self),
      postID: row["post_id"].decode(UUID.self),
      threadID: row["thread_id"].decode(UUID.self),
      authorType: try decodeEnum(
        OrbitParticipantAuthorType.self,
        from: row["author_type"],
        columnName: "author_type"
      ),
      authorID: row["author_id"].decode(String.self),
      replyToMessageID: row["reply_to_message_id"].decode(Optional<UUID>.self),
      body: row["body"].decode(String.self),
      messageFormat: try decodeEnum(
        OrbitMessageFormat.self,
        from: row["message_format"],
        columnName: "message_format"
      ),
      state: try decodeEnum(
        OrbitMessageState.self,
        from: row["state"],
        columnName: "state"
      ),
      createdAt: row["created_at"].decode(Date.self),
      updatedAt: row["updated_at"].decode(Date.self)
    )
  }

  private func decodePostParticipant(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitPostParticipantRecord {
    try OrbitPostParticipantRecord(
      id: row["id"].decode(UUID.self),
      postID: row["post_id"].decode(UUID.self),
      participantType: try decodeEnum(
        OrbitParticipantAuthorType.self,
        from: row["participant_type"],
        columnName: "participant_type"
      ),
      participantID: row["participant_id"].decode(String.self),
      joinedAt: row["joined_at"].decode(Date.self),
      leftAt: row["left_at"].decode(Optional<Date>.self),
      participationMode: try decodeEnum(
        OrbitParticipationMode.self,
        from: row["participation_mode"],
        columnName: "participation_mode"
      )
    )
  }

  private func decodePostEvent(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitPostEventRecord {
    let payloadData = row[data: "payload"]
    var payloadBuffer = payloadData.value
    if payloadData.type == .jsonb {
      payloadBuffer?.moveReaderIndex(forwardBy: 1)
    }
    let payloadJSONString = payloadBuffer.map { buffer in
      String(decoding: buffer.readableBytesView, as: UTF8.self)
    } ?? "null"

    return try OrbitPostEventRecord(
      id: row["id"].decode(UUID.self),
      postID: row["post_id"].decode(UUID.self),
      threadID: row["thread_id"].decode(Optional<UUID>.self),
      eventType: row["event_type"].decode(String.self),
      payloadJSON: payloadJSONString,
      createdAt: row["created_at"].decode(Date.self)
    )
  }

  private func decodeRealtimeEvent(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitPhase1RealtimeEventEnvelope {
    let payloadData = row[data: "payload"]
    var payloadBuffer = payloadData.value
    if payloadData.type == .jsonb {
      payloadBuffer?.moveReaderIndex(forwardBy: 1)
    }
    let payloadJSONString = payloadBuffer.map { buffer in
      String(decoding: buffer.readableBytesView, as: UTF8.self)
    } ?? "null"

    return try OrbitPhase1RealtimeEventEnvelope(
      id: row["id"].decode(UUID.self),
      workspaceID: row["workspace_id"].decode(UUID.self),
      postID: row["post_id"].decode(Optional<UUID>.self),
      threadID: row["thread_id"].decode(Optional<UUID>.self),
      category: decodeEnum(
        OrbitPhase1RealtimeEventCategory.self,
        from: row["category"],
        columnName: "category"
      ),
      createdAt: row["created_at"].decode(Date.self),
      payloadJSON: payloadJSONString
    )
  }

  private func decodePersonaActivation(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitPersonaActivationRecord {
    try OrbitPersonaActivationRecord(
      id: row["activation_id"].decode(UUID.self),
      initiatedByParticipantType: try decodeEnum(
        OrbitParticipantAuthorType.self,
        from: row["activation_initiated_by_participant_type"],
        columnName: "activation_initiated_by_participant_type"
      ),
      initiatedByParticipantID: row["activation_initiated_by_participant_id"].decode(String.self),
      workspaceID: row["activation_workspace_id"].decode(UUID.self),
      channelID: row["activation_channel_id"].decode(Optional<UUID>.self),
      originPostID: row["activation_origin_post_id"].decode(UUID.self),
      originThreadID: row["activation_origin_thread_id"].decode(UUID.self),
      triggerMessageID: row["activation_trigger_message_id"].decode(UUID.self),
      addressedTargetKind: try decodeEnum(
        OrbitAddressedTargetKind.self,
        from: row["activation_addressed_target_kind"],
        columnName: "activation_addressed_target_kind"
      ),
      addressedTargetReferenceID: row["activation_addressed_target_reference_id"].decode(String.self),
      resolvedWorkspacePersonaInstanceID: row["activation_resolved_workspace_persona_instance_id"].decode(UUID.self),
      responseMode: try decodeEnum(
        OrbitCanonicalResponseMode.self,
        from: row["activation_response_mode"],
        columnName: "activation_response_mode"
      ),
      createdAt: row["activation_created_at"].decode(Date.self)
    )
  }

  private func decodeAgentRun(
    from row: PostgresRandomAccessRow
  ) throws -> OrbitAgentRunRecord? {
    let runID = try row["run_id"].decode(Optional<UUID>.self)

    guard let runID else {
      return nil
    }

    return try OrbitAgentRunRecord(
      id: runID,
      personaActivationID: row["activation_id"].decode(UUID.self),
      runnerKind: row["run_runner_kind"].decode(String.self),
      status: try decodeEnum(
        OrbitAgentRunStatus.self,
        from: row["run_status"],
        columnName: "run_status"
      ),
      startedAt: row["run_started_at"].decode(Date.self),
      completedAt: row["run_completed_at"].decode(Optional<Date>.self),
      failureReason: row["run_failure_reason"].decode(Optional<String>.self)
    )
  }

  private func decodeEnum<Value: RawRepresentable>(
    _ type: Value.Type,
    from cell: PostgresCell,
    columnName: String
  ) throws -> Value where Value.RawValue == String {
    let rawValue = try cell.decode(String.self)

    guard let value = Value(rawValue: rawValue) else {
      throw OrbitPostgresRuntimeStoreError.invalidEnumValue(
        column: columnName,
        rawValue: rawValue
      )
    }

    return value
  }
}

public enum OrbitPostgresRuntimeStoreError: Error, Equatable {
  case invalidEnumValue(column: String, rawValue: String)
}
