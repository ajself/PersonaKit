import Foundation
import PostgresNIO

public struct OrbitPhase1RuntimeRepository: Sendable {
  public init() {}

  public func bootstrapRoom(
    _ room: OrbitPhase1RoomBootstrap,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    let realtimeEvents = try room.realtimeEvents.isEmpty
      ? OrbitPhase1RealtimeEventProjector.bootstrapEvents(for: room)
      : room.realtimeEvents

    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: upsertWorkspaceQuery(room.workspace))
      try await executor.execute(query: upsertChannelQuery(room.channel))

      for workspacePersona in room.workspacePersonas {
        try await executor.execute(query: upsertWorkspacePersonaQuery(workspacePersona))
      }

      for team in room.teams {
        try await executor.execute(query: upsertTeamQuery(team))
      }

      for squad in room.squads {
        try await executor.execute(query: upsertSquadQuery(squad))
      }

      for membership in room.workspacePersonaMemberships {
        try await executor.execute(query: upsertWorkspacePersonaMembershipQuery(membership))
      }

      try await executor.execute(query: insertPostQuery(room.post))
      try await executor.execute(query: insertThreadQuery(room.thread))

      for realtimeEvent in realtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }

      for postParticipant in room.postParticipants {
        try await executor.execute(query: insertPostParticipantQuery(postParticipant))
      }

      if let meetingState = room.meetingState {
        try await executor.execute(query: upsertMeetingStateQuery(meetingState))
      }

      for meetingMember in room.meetingMembers {
        try await executor.execute(query: upsertMeetingMemberQuery(meetingMember))
      }

      for message in room.seedMessages {
        try await executor.execute(query: insertMessageQuery(message))
      }

      for postEvent in room.postEvents {
        try await executor.execute(query: insertPostEventQuery(postEvent))
      }

      for personaActivation in room.personaActivations {
        try await executor.execute(query: insertPersonaActivationQuery(personaActivation))
      }

      for agentRun in room.agentRuns {
        try await executor.execute(query: insertAgentRunQuery(agentRun))
      }

      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func appendMessage(
    workspaceID: UUID,
    _ message: OrbitMessageRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    meetingState: OrbitMeetingStateRecord? = nil,
    threadLastActivityAt: Date,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    let effectiveRealtimeEvents = try realtimeEvents.isEmpty
      ? OrbitPhase1RealtimeEventProjector.appendEvents(
          workspaceID: workspaceID,
          message: message,
          threadLastActivityAt: threadLastActivityAt
        )
      : realtimeEvents

    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: insertMessageQuery(message))
      for realtimeEvent in effectiveRealtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }
      if let meetingState {
        try await executor.execute(query: upsertMeetingStateQuery(meetingState))
      }
      try await executor.execute(
        query: updateThreadActivityQuery(
          threadID: message.threadID,
          lastActivityAt: threadLastActivityAt
        )
      )
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func appendCollaboratorResponse(
    workspaceID: UUID,
    _ message: OrbitMessageRecord,
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    meetingState: OrbitMeetingStateRecord? = nil,
    threadLastActivityAt: Date,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: insertMessageQuery(message))
      try await executor.execute(query: insertPersonaActivationQuery(activation))
      try await executor.execute(query: insertAgentRunQuery(agentRun))
      try await executor.execute(query: insertPostEventQuery(postEvent))
      for realtimeEvent in realtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }
      if let meetingState {
        try await executor.execute(query: upsertMeetingStateQuery(meetingState))
      }
      try await executor.execute(
        query: updateThreadActivityQuery(
          threadID: message.threadID,
          lastActivityAt: threadLastActivityAt
        )
      )
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func appendActivationFailure(
    workspaceID: UUID,
    _ systemMessage: OrbitMessageRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    meetingState: OrbitMeetingStateRecord? = nil,
    threadLastActivityAt: Date,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: insertMessageQuery(systemMessage))
      try await executor.execute(query: insertPostEventQuery(postEvent))
      for realtimeEvent in realtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }
      if let meetingState {
        try await executor.execute(query: upsertMeetingStateQuery(meetingState))
      }
      try await executor.execute(
        query: updateThreadActivityQuery(
          threadID: systemMessage.threadID,
          lastActivityAt: threadLastActivityAt
        )
      )
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func upsertWorkspaceQuery(
    _ workspace: OrbitWorkspaceRecord
  ) -> PostgresQuery {
    """
    INSERT INTO workspace (
      id, slug, name, status, created_at, archived_at
    ) VALUES (
      \(workspace.id),
      \(workspace.slug),
      \(workspace.name),
      \(workspace.status.rawValue),
      \(workspace.createdAt),
      \(workspace.archivedAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      slug = EXCLUDED.slug,
      name = EXCLUDED.name,
      status = EXCLUDED.status,
      archived_at = EXCLUDED.archived_at
    """
  }

  public func upsertChannelQuery(
    _ channel: OrbitChannelRecord
  ) -> PostgresQuery {
    """
    INSERT INTO channel (
      id, workspace_id, slug, name, purpose, status, created_at, archived_at
    ) VALUES (
      \(channel.id),
      \(channel.workspaceID),
      \(channel.slug),
      \(channel.name),
      \(channel.purpose),
      \(channel.status.rawValue),
      \(channel.createdAt),
      \(channel.archivedAt)
    )
    ON CONFLICT (workspace_id, slug) DO UPDATE SET
      name = EXCLUDED.name,
      purpose = EXCLUDED.purpose,
      status = EXCLUDED.status,
      archived_at = EXCLUDED.archived_at
    """
  }

  public func upsertWorkspacePersonaQuery(
    _ workspacePersona: OrbitWorkspacePersonaRecord
  ) -> PostgresQuery {
    """
    INSERT INTO workspace_persona (
      id, workspace_id, persona_template_id, display_name,
      default_directive_override_id, status, created_at, archived_at
    ) VALUES (
      \(workspacePersona.id),
      \(workspacePersona.workspaceID),
      \(workspacePersona.personaTemplateID),
      \(workspacePersona.displayName),
      \(workspacePersona.defaultDirectiveOverrideID),
      \(workspacePersona.status.rawValue),
      \(workspacePersona.createdAt),
      \(workspacePersona.archivedAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      persona_template_id = EXCLUDED.persona_template_id,
      display_name = EXCLUDED.display_name,
      default_directive_override_id = EXCLUDED.default_directive_override_id,
      status = EXCLUDED.status,
      archived_at = EXCLUDED.archived_at
    """
  }

  public func upsertTeamQuery(
    _ team: OrbitTeamRecord
  ) -> PostgresQuery {
    """
    INSERT INTO team (
      id, workspace_id, slug, name, purpose, created_at
    ) VALUES (
      \(team.id),
      \(team.workspaceID),
      \(team.slug),
      \(team.name),
      \(team.purpose),
      \(team.createdAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      slug = EXCLUDED.slug,
      name = EXCLUDED.name,
      purpose = EXCLUDED.purpose
    """
  }

  public func upsertSquadQuery(
    _ squad: OrbitSquadRecord
  ) -> PostgresQuery {
    """
    INSERT INTO squad (
      id, workspace_id, team_id, slug, name, purpose, created_at
    ) VALUES (
      \(squad.id),
      \(squad.workspaceID),
      \(squad.teamID),
      \(squad.slug),
      \(squad.name),
      \(squad.purpose),
      \(squad.createdAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      team_id = EXCLUDED.team_id,
      slug = EXCLUDED.slug,
      name = EXCLUDED.name,
      purpose = EXCLUDED.purpose
    """
  }

  public func upsertWorkspacePersonaMembershipQuery(
    _ membership: OrbitWorkspacePersonaMembershipRecord
  ) -> PostgresQuery {
    if let teamID = membership.teamID {
      return """
      INSERT INTO workspace_persona_membership (
        id, workspace_persona_id, team_id, squad_id, role_in_group, created_at
      )
      SELECT
        \(membership.id),
        \(membership.workspacePersonaID),
        \(membership.teamID),
        \(membership.squadID),
        \(membership.roleInGroup),
        \(membership.createdAt)
      WHERE NOT EXISTS (
        SELECT 1
        FROM workspace_persona_membership
        WHERE id <> \(membership.id)
          AND workspace_persona_id = \(membership.workspacePersonaID)
          AND team_id = \(teamID)
      )
      ON CONFLICT (id) DO UPDATE SET
        workspace_persona_id = EXCLUDED.workspace_persona_id,
        team_id = EXCLUDED.team_id,
        squad_id = EXCLUDED.squad_id,
        role_in_group = EXCLUDED.role_in_group
      """
    }

    if let squadID = membership.squadID {
      return """
      INSERT INTO workspace_persona_membership (
        id, workspace_persona_id, team_id, squad_id, role_in_group, created_at
      )
      SELECT
        \(membership.id),
        \(membership.workspacePersonaID),
        \(membership.teamID),
        \(membership.squadID),
        \(membership.roleInGroup),
        \(membership.createdAt)
      WHERE NOT EXISTS (
        SELECT 1
        FROM workspace_persona_membership
        WHERE id <> \(membership.id)
          AND workspace_persona_id = \(membership.workspacePersonaID)
          AND squad_id = \(squadID)
      )
      ON CONFLICT (id) DO UPDATE SET
        workspace_persona_id = EXCLUDED.workspace_persona_id,
        team_id = EXCLUDED.team_id,
        squad_id = EXCLUDED.squad_id,
        role_in_group = EXCLUDED.role_in_group
      """
    }

    return """
    INSERT INTO workspace_persona_membership (
      id, workspace_persona_id, team_id, squad_id, role_in_group, created_at
    )
    VALUES (
      \(membership.id),
      \(membership.workspacePersonaID),
      \(membership.teamID),
      \(membership.squadID),
      \(membership.roleInGroup),
      \(membership.createdAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      workspace_persona_id = EXCLUDED.workspace_persona_id,
      team_id = EXCLUDED.team_id,
      squad_id = EXCLUDED.squad_id,
      role_in_group = EXCLUDED.role_in_group
    """
  }

  public func insertPostQuery(
    _ post: OrbitPostRecord
  ) -> PostgresQuery {
    """
    INSERT INTO post (
      id, workspace_id, channel_id, post_type, created_by_participant_type,
      created_by_participant_id, title, status, created_at, archived_at
    ) VALUES (
      \(post.id),
      \(post.workspaceID),
      \(post.channelID),
      \(post.postType.rawValue),
      \(post.createdByParticipantType.rawValue),
      \(post.createdByParticipantID),
      \(post.title),
      \(post.status.rawValue),
      \(post.createdAt),
      \(post.archivedAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertThreadQuery(
    _ thread: OrbitThreadRecord
  ) -> PostgresQuery {
    """
    INSERT INTO thread (
      id, post_id, status, last_activity_at, created_at, closed_at
    ) VALUES (
      \(thread.id),
      \(thread.postID),
      \(thread.status.rawValue),
      \(thread.lastActivityAt),
      \(thread.createdAt),
      \(thread.closedAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertMessageQuery(
    _ message: OrbitMessageRecord
  ) -> PostgresQuery {
    """
    INSERT INTO message (
      id, post_id, thread_id, author_type, author_id, reply_to_message_id,
      body, message_format, state, created_at, updated_at
    ) VALUES (
      \(message.id),
      \(message.postID),
      \(message.threadID),
      \(message.authorType.rawValue),
      \(message.authorID),
      \(message.replyToMessageID),
      \(message.body),
      \(message.messageFormat.rawValue),
      \(message.state.rawValue),
      \(message.createdAt),
      \(message.updatedAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertRealtimeEventQuery(
    _ event: OrbitRealtimeEventRecord
  ) -> PostgresQuery {
    """
    INSERT INTO realtime_event (
      id, workspace_id, post_id, thread_id, category, payload, created_at
    ) VALUES (
      \(event.id),
      \(event.workspaceID),
      \(event.postID),
      \(event.threadID),
      \(event.category.rawValue),
      \(event.payloadJSON)::jsonb,
      \(event.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertPostParticipantQuery(
    _ participant: OrbitPostParticipantRecord
  ) -> PostgresQuery {
    """
    INSERT INTO post_participant (
      id, post_id, participant_type, participant_id, joined_at, left_at,
      participation_mode
    ) VALUES (
      \(participant.id),
      \(participant.postID),
      \(participant.participantType.rawValue),
      \(participant.participantID),
      \(participant.joinedAt),
      \(participant.leftAt),
      \(participant.participationMode.rawValue)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertPostEventQuery(
    _ event: OrbitPostEventRecord
  ) -> PostgresQuery {
    """
    INSERT INTO post_event (
      id, post_id, thread_id, event_type, payload, created_at
    ) VALUES (
      \(event.id),
      \(event.postID),
      \(event.threadID),
      \(event.eventType),
      \(event.payloadJSON)::jsonb,
      \(event.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func upsertMeetingStateQuery(
    _ meetingState: OrbitMeetingStateRecord
  ) -> PostgresQuery {
    """
    INSERT INTO meeting_state (
      post_id, meeting_type, status, started_by_participant_type,
      started_by_participant_id, started_at, completed_at
    ) VALUES (
      \(meetingState.postID),
      \(meetingState.meetingType.rawValue),
      \(meetingState.status.rawValue),
      \(meetingState.startedByParticipantType.rawValue),
      \(meetingState.startedByParticipantID),
      \(meetingState.startedAt),
      \(meetingState.completedAt)
    )
    ON CONFLICT (post_id) DO UPDATE SET
      meeting_type = EXCLUDED.meeting_type,
      status = EXCLUDED.status,
      started_by_participant_type = EXCLUDED.started_by_participant_type,
      started_by_participant_id = EXCLUDED.started_by_participant_id,
      started_at = EXCLUDED.started_at,
      completed_at = EXCLUDED.completed_at
    """
  }

  public func upsertMeetingMemberQuery(
    _ meetingMember: OrbitMeetingMemberRecord
  ) -> PostgresQuery {
    """
    INSERT INTO meeting_member (
      id, meeting_post_id, post_participant_id, participation_role,
      selected_reason, joined_at, completed_at
    ) VALUES (
      \(meetingMember.id),
      \(meetingMember.meetingPostID),
      \(meetingMember.postParticipantID),
      \(meetingMember.participationRole.rawValue),
      \(meetingMember.selectedReason),
      \(meetingMember.joinedAt),
      \(meetingMember.completedAt)
    )
    ON CONFLICT (meeting_post_id, post_participant_id) DO UPDATE SET
      participation_role = EXCLUDED.participation_role,
      selected_reason = EXCLUDED.selected_reason,
      joined_at = EXCLUDED.joined_at,
      completed_at = EXCLUDED.completed_at
    """
  }

  public func insertPersonaActivationQuery(
    _ activation: OrbitPersonaActivationRecord
  ) -> PostgresQuery {
    """
    INSERT INTO persona_activation (
      id, initiated_by_participant_type, initiated_by_participant_id, workspace_id,
      channel_id, origin_post_id, origin_thread_id, trigger_message_id,
      addressed_target_kind, addressed_target_reference_id,
      resolved_workspace_persona_instance_id, response_mode, created_at
    ) VALUES (
      \(activation.id),
      \(activation.initiatedByParticipantType.rawValue),
      \(activation.initiatedByParticipantID),
      \(activation.workspaceID),
      \(activation.channelID),
      \(activation.originPostID),
      \(activation.originThreadID),
      \(activation.triggerMessageID),
      \(activation.addressedTargetKind.rawValue),
      \(activation.addressedTargetReferenceID),
      \(activation.resolvedWorkspacePersonaInstanceID),
      \(activation.responseMode.rawValue),
      \(activation.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertAgentRunQuery(
    _ agentRun: OrbitAgentRunRecord
  ) -> PostgresQuery {
    """
    INSERT INTO agent_run (
      id, persona_activation_id, runner_kind, status, started_at, completed_at,
      failure_reason
    ) VALUES (
      \(agentRun.id),
      \(agentRun.personaActivationID),
      \(agentRun.runnerKind),
      \(agentRun.status.rawValue),
      \(agentRun.startedAt),
      \(agentRun.completedAt),
      \(agentRun.failureReason)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func selectRoomSnapshotQuery(
    workspaceSlug: String,
    channelSlug: String
  ) -> PostgresQuery {
    """
    SELECT
      workspace.id AS workspace_id,
      workspace.slug AS workspace_slug,
      workspace.name AS workspace_name,
      workspace.status AS workspace_status,
      workspace.created_at AS workspace_created_at,
      workspace.archived_at AS workspace_archived_at,
      channel.id AS channel_id,
      channel.slug AS channel_slug,
      channel.name AS channel_name,
      channel.purpose AS channel_purpose,
      channel.status AS channel_status,
      channel.created_at AS channel_created_at,
      channel.archived_at AS channel_archived_at,
      post.id AS post_id,
      post.workspace_id AS post_workspace_id,
      post.channel_id AS post_channel_id,
      post.post_type AS post_type,
      post.created_by_participant_type AS post_created_by_participant_type,
      post.created_by_participant_id AS post_created_by_participant_id,
      post.title AS post_title,
      post.status AS post_status,
      post.created_at AS post_created_at,
      post.archived_at AS post_archived_at,
      thread.id AS thread_id,
      thread.post_id AS thread_post_id,
      thread.status AS thread_status,
      thread.last_activity_at AS thread_last_activity_at,
      thread.created_at AS thread_created_at,
      thread.closed_at AS thread_closed_at
    FROM workspace
    JOIN channel ON channel.workspace_id = workspace.id
    JOIN post ON post.channel_id = channel.id
    JOIN thread ON thread.post_id = post.id
    WHERE workspace.slug = \(workspaceSlug)
      AND channel.slug = \(channelSlug)
    ORDER BY post.created_at ASC, thread.created_at ASC
    LIMIT 1
    """
  }

  public func selectThreadMessagesQuery(
    threadID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      thread_id,
      author_type,
      author_id,
      reply_to_message_id,
      body,
      message_format,
      state,
      created_at,
      updated_at
    FROM message
    WHERE thread_id = \(threadID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectWorkspacePersonasQuery(
    workspaceID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      workspace_id,
      persona_template_id,
      display_name,
      default_directive_override_id,
      status,
      created_at,
      archived_at
    FROM workspace_persona
    WHERE workspace_id = \(workspaceID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectTeamsQuery(
    workspaceID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      workspace_id,
      slug,
      name,
      purpose,
      created_at
    FROM team
    WHERE workspace_id = \(workspaceID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectSquadsQuery(
    workspaceID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      workspace_id,
      team_id,
      slug,
      name,
      purpose,
      created_at
    FROM squad
    WHERE workspace_id = \(workspaceID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectWorkspacePersonaMembershipsQuery(
    workspaceID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      workspace_persona_membership.id,
      workspace_persona_membership.workspace_persona_id,
      workspace_persona_membership.team_id,
      workspace_persona_membership.squad_id,
      workspace_persona_membership.role_in_group,
      workspace_persona_membership.created_at
    FROM workspace_persona_membership
    JOIN workspace_persona
      ON workspace_persona.id = workspace_persona_membership.workspace_persona_id
    WHERE workspace_persona.workspace_id = \(workspaceID)
    ORDER BY workspace_persona_membership.created_at ASC, workspace_persona_membership.id ASC
    """
  }

  public func selectRealtimeEventsQuery(
    workspaceID: UUID,
    after cursor: OrbitPhase1ReplayCursor?
  ) -> PostgresQuery {
    if let cursor,
      let lastEventCreatedAt = cursor.lastEventCreatedAt,
      let lastEventID = cursor.lastEventID
    {
      return """
      SELECT
        id,
        workspace_id,
        post_id,
        thread_id,
        category,
        payload,
        created_at
      FROM realtime_event
      WHERE workspace_id = \(workspaceID)
        AND (
          created_at > \(lastEventCreatedAt)
          OR (created_at = \(lastEventCreatedAt) AND id > \(lastEventID))
        )
      ORDER BY created_at ASC, id ASC
      """
    }

    return """
    SELECT
      id,
      workspace_id,
      post_id,
      thread_id,
      category,
      payload,
      created_at
    FROM realtime_event
    WHERE workspace_id = \(workspaceID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectPostParticipantsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      participant_type,
      participant_id,
      joined_at,
      left_at,
      participation_mode
    FROM post_participant
    WHERE post_id = \(postID)
    ORDER BY joined_at ASC, id ASC
    """
  }

  public func selectPostEventsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      thread_id,
      event_type,
      payload,
      created_at
    FROM post_event
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectMeetingStateQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      post_id,
      meeting_type,
      status,
      started_by_participant_type,
      started_by_participant_id,
      started_at,
      completed_at
    FROM meeting_state
    WHERE post_id = \(postID)
    """
  }

  public func selectMeetingMembersQuery(
    meetingPostID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      meeting_post_id,
      post_participant_id,
      participation_role,
      selected_reason,
      joined_at,
      completed_at
    FROM meeting_member
    WHERE meeting_post_id = \(meetingPostID)
    ORDER BY joined_at ASC, id ASC
    """
  }

  public func selectPostActivationsAndRunsQuery(
    originPostID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      persona_activation.id AS activation_id,
      persona_activation.initiated_by_participant_type AS activation_initiated_by_participant_type,
      persona_activation.initiated_by_participant_id AS activation_initiated_by_participant_id,
      persona_activation.workspace_id AS activation_workspace_id,
      persona_activation.channel_id AS activation_channel_id,
      persona_activation.origin_post_id AS activation_origin_post_id,
      persona_activation.origin_thread_id AS activation_origin_thread_id,
      persona_activation.trigger_message_id AS activation_trigger_message_id,
      persona_activation.addressed_target_kind AS activation_addressed_target_kind,
      persona_activation.addressed_target_reference_id AS activation_addressed_target_reference_id,
      persona_activation.resolved_workspace_persona_instance_id AS activation_resolved_workspace_persona_instance_id,
      persona_activation.response_mode AS activation_response_mode,
      persona_activation.created_at AS activation_created_at,
      agent_run.id AS run_id,
      agent_run.runner_kind AS run_runner_kind,
      agent_run.status AS run_status,
      agent_run.started_at AS run_started_at,
      agent_run.completed_at AS run_completed_at,
      agent_run.failure_reason AS run_failure_reason
    FROM persona_activation
    LEFT JOIN agent_run ON agent_run.persona_activation_id = persona_activation.id
    WHERE persona_activation.origin_post_id = \(originPostID)
    ORDER BY persona_activation.created_at ASC, agent_run.started_at ASC NULLS FIRST
    """
  }

  public func updateThreadActivityQuery(
    threadID: UUID,
    lastActivityAt: Date
  ) -> PostgresQuery {
    """
    UPDATE thread
    SET last_activity_at = \(lastActivityAt)
    WHERE id = \(threadID)
    """
  }
}
