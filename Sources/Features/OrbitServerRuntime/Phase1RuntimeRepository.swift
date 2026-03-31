import Foundation
import PostgresNIO

public struct OrbitPhase1RuntimeRepository: Sendable {
  public init() {}

  public func bootstrapRoom(
    _ room: OrbitPhase1RoomBootstrap,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executeBootstrapRoomQueries(room, using: executor)
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func promoteMeetingRoom(
    originPostEvent: OrbitPostEventRecord,
    originRealtimeEvents: [OrbitRealtimeEventRecord],
    room: OrbitPhase1RoomBootstrap,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: insertPostEventQuery(originPostEvent))

      for realtimeEvent in originRealtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }

      try await executeBootstrapRoomQueries(room, using: executor)
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
    let effectiveRealtimeEvents =
      try realtimeEvents.isEmpty
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

  public func appendPostEvent(
    workspaceID: UUID,
    _ postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: insertPostEventQuery(postEvent))
      for realtimeEvent in realtimeEvents {
        try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
      }
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func completeMeeting(
    workspaceID: UUID,
    summaryNote: OrbitNoteRecord,
    meetingOutputState: OrbitMeetingOutputStateRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord],
    structuredAttachments: [OrbitStructuredAttachmentRecord],
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord],
    meetingState: OrbitMeetingStateRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    threadID: UUID,
    threadLastActivityAt: Date,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await completeMeetingTransactionally(
        workspaceID: workspaceID,
        summaryNote: summaryNote,
        meetingOutputState: meetingOutputState,
        decision: decision,
        references: references,
        structuredAttachments: structuredAttachments,
        meetingOpenQuestions: meetingOpenQuestions,
        meetingState: meetingState,
        postEvent: postEvent,
        realtimeEvents: realtimeEvents,
        threadID: threadID,
        threadLastActivityAt: threadLastActivityAt,
        using: executor
      )
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  public func completeMeetingTransactionally(
    workspaceID _: UUID,
    summaryNote: OrbitNoteRecord,
    meetingOutputState: OrbitMeetingOutputStateRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord],
    structuredAttachments: [OrbitStructuredAttachmentRecord],
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord],
    meetingState: OrbitMeetingStateRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    threadID: UUID,
    threadLastActivityAt: Date,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    try await executor.execute(query: upsertNoteQuery(summaryNote))
    try await executor.execute(query: upsertMeetingOutputStateQuery(meetingOutputState))

    if let decision {
      try await executor.execute(query: insertDecisionQuery(decision))
    }

    for reference in references {
      try await executor.execute(query: insertReferenceQuery(reference))
    }

    for structuredAttachment in structuredAttachments {
      try await executor.execute(query: upsertStructuredAttachmentQuery(structuredAttachment))
    }

    for meetingOpenQuestion in meetingOpenQuestions {
      try await executor.execute(query: insertMeetingOpenQuestionQuery(meetingOpenQuestion))
    }

    try await executor.execute(query: upsertMeetingStateQuery(meetingState))
    try await executor.execute(query: insertPostEventQuery(postEvent))

    for realtimeEvent in realtimeEvents {
      try await executor.execute(query: insertRealtimeEventQuery(realtimeEvent))
    }

    try await executor.execute(
      query: updateThreadActivityQuery(
        threadID: threadID,
        lastActivityAt: threadLastActivityAt
      )
    )
  }

  public func recordApprovedMemory(
    _ bundle: OrbitApprovedMemoryRecordBundle,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    do {
      try await executor.execute(query: .init(unsafeSQL: "BEGIN"))
      try await executor.execute(query: upsertMemoryCandidateQuery(bundle.candidate))
      try await executor.execute(query: insertMemoryReviewQuery(bundle.review))
      try await executor.execute(query: upsertMemoryEntryQuery(bundle.entry))
      if let personaGlobalProfile = bundle.personaGlobalProfile {
        try await executor.execute(
          query: upsertPersonaGlobalMemoryProfileQuery(personaGlobalProfile)
        )
      }
      try await executor.execute(query: .init(unsafeSQL: "COMMIT"))
    } catch {
      try? await executor.execute(query: .init(unsafeSQL: "ROLLBACK"))
      throw error
    }
  }

  private func executeBootstrapRoomQueries(
    _ room: OrbitPhase1RoomBootstrap,
    using executor: some OrbitPostgresStatementExecutor
  ) async throws {
    let realtimeEvents =
      try room.realtimeEvents.isEmpty
      ? OrbitPhase1RealtimeEventProjector.bootstrapEvents(for: room)
      : room.realtimeEvents

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

    for postLink in room.postLinks {
      try await executor.execute(query: insertPostLinkQuery(postLink))
    }

    for note in room.notes {
      try await executor.execute(query: insertNoteQuery(note))
    }

    for decision in room.decisions {
      try await executor.execute(query: insertDecisionQuery(decision))
    }

    for reference in room.references {
      try await executor.execute(query: insertReferenceQuery(reference))
    }

    for artifact in room.artifacts {
      try await executor.execute(query: insertArtifactQuery(artifact))
    }

    for structuredAttachment in room.structuredAttachments {
      try await executor.execute(query: upsertStructuredAttachmentQuery(structuredAttachment))
    }

    if let meetingOutputState = room.meetingOutputState {
      try await executor.execute(query: upsertMeetingOutputStateQuery(meetingOutputState))
    }

    for meetingOpenQuestion in room.meetingOpenQuestions {
      try await executor.execute(query: insertMeetingOpenQuestionQuery(meetingOpenQuestion))
    }

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

  public func insertPostLinkQuery(
    _ postLink: OrbitPostLinkRecord
  ) -> PostgresQuery {
    """
    INSERT INTO post_link (
      id, from_post_id, to_post_id, link_type, created_at
    ) VALUES (
      \(postLink.id),
      \(postLink.fromPostID),
      \(postLink.toPostID),
      \(postLink.linkType.rawValue),
      \(postLink.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertNoteQuery(
    _ note: OrbitNoteRecord
  ) -> PostgresQuery {
    """
    INSERT INTO note (
      id, post_id, note_type, body, created_by_participant_type,
      created_by_participant_id, created_at
    ) VALUES (
      \(note.id),
      \(note.postID),
      \(note.noteType.rawValue),
      \(note.body),
      \(note.createdByParticipantType.rawValue),
      \(note.createdByParticipantID),
      \(note.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func upsertNoteQuery(
    _ note: OrbitNoteRecord
  ) -> PostgresQuery {
    """
    INSERT INTO note (
      id, post_id, note_type, body, created_by_participant_type,
      created_by_participant_id, created_at
    ) VALUES (
      \(note.id),
      \(note.postID),
      \(note.noteType.rawValue),
      \(note.body),
      \(note.createdByParticipantType.rawValue),
      \(note.createdByParticipantID),
      \(note.createdAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      body = EXCLUDED.body
    """
  }

  public func upsertStructuredAttachmentQuery(
    _ attachment: OrbitStructuredAttachmentRecord
  ) -> PostgresQuery {
    """
    INSERT INTO structured_attachment (
      origin_post_id, structured_object_type, structured_object_id,
      attachment_ordinal, attached_at
    ) VALUES (
      \(attachment.originPostID),
      \(attachment.structuredObjectType.rawValue),
      \(attachment.structuredObjectID),
      \(attachment.attachmentOrdinal),
      \(attachment.attachedAt)
    )
    ON CONFLICT (structured_object_type, structured_object_id) DO UPDATE SET
      origin_post_id = EXCLUDED.origin_post_id,
      attachment_ordinal = EXCLUDED.attachment_ordinal,
      attached_at = EXCLUDED.attached_at
    """
  }

  public func insertDecisionQuery(
    _ decision: OrbitDecisionRecord
  ) -> PostgresQuery {
    """
    INSERT INTO decision (
      id, post_id, title, body, decision_state, rationale, tradeoffs, dissent,
      linked_reference_ids, rationale_note_id, created_by_participant_type,
      created_by_participant_id, created_at
    ) VALUES (
      \(decision.id),
      \(decision.postID),
      \(decision.title),
      \(decision.body),
      \(decision.decisionState.rawValue),
      \(decision.rationale),
      \(decision.tradeoffs),
      \(decision.dissent),
      \(decision.linkedReferenceIDs.jsonString)::jsonb,
      \(decision.rationaleNoteID),
      \(decision.createdByParticipantType.rawValue),
      \(decision.createdByParticipantID),
      \(decision.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertReferenceQuery(
    _ reference: OrbitReferenceRecord
  ) -> PostgresQuery {
    """
    INSERT INTO reference (
      id, post_id, reference_type, target, title, created_by_participant_type,
      created_by_participant_id, created_at
    ) VALUES (
      \(reference.id),
      \(reference.postID),
      \(reference.referenceType.rawValue),
      \(reference.target),
      \(reference.title),
      \(reference.createdByParticipantType.rawValue),
      \(reference.createdByParticipantID),
      \(reference.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func insertArtifactQuery(
    _ artifact: OrbitArtifactRecord
  ) -> PostgresQuery {
    """
    INSERT INTO artifact (
      id, post_id, artifact_type, storage_ref, title,
      created_by_participant_type, created_by_participant_id, created_at
    ) VALUES (
      \(artifact.id),
      \(artifact.postID),
      \(artifact.artifactType.rawValue),
      \(artifact.storageRef),
      \(artifact.title),
      \(artifact.createdByParticipantType.rawValue),
      \(artifact.createdByParticipantID),
      \(artifact.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func upsertMeetingOutputStateQuery(
    _ meetingOutputState: OrbitMeetingOutputStateRecord
  ) -> PostgresQuery {
    """
    INSERT INTO meeting_output_state (
      post_id, outcome_state, detail, recorded_by_participant_type,
      recorded_by_participant_id, recorded_at
    ) VALUES (
      \(meetingOutputState.postID),
      \(meetingOutputState.outcomeState.rawValue),
      \(meetingOutputState.detail),
      \(meetingOutputState.recordedByParticipantType.rawValue),
      \(meetingOutputState.recordedByParticipantID),
      \(meetingOutputState.recordedAt)
    )
    ON CONFLICT (post_id) DO UPDATE SET
      outcome_state = EXCLUDED.outcome_state,
      detail = EXCLUDED.detail,
      recorded_by_participant_type = EXCLUDED.recorded_by_participant_type,
      recorded_by_participant_id = EXCLUDED.recorded_by_participant_id,
      recorded_at = EXCLUDED.recorded_at
    """
  }

  public func insertMeetingOpenQuestionQuery(
    _ meetingOpenQuestion: OrbitMeetingOpenQuestionRecord
  ) -> PostgresQuery {
    """
    INSERT INTO meeting_open_question (
      id, post_id, body, created_by_participant_type, created_by_participant_id,
      created_at
    ) VALUES (
      \(meetingOpenQuestion.id),
      \(meetingOpenQuestion.postID),
      \(meetingOpenQuestion.body),
      \(meetingOpenQuestion.createdByParticipantType.rawValue),
      \(meetingOpenQuestion.createdByParticipantID),
      \(meetingOpenQuestion.createdAt)
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

  public func upsertMemoryCandidateQuery(
    _ candidate: OrbitMemoryCandidateRecord
  ) -> PostgresQuery {
    """
    INSERT INTO memory_candidate (
      id, workspace_id, workspace_persona_id, persona_template_id, source_type,
      source_id, proposed_scope, title, body, confidence, status, created_at,
      reviewed_at
    ) VALUES (
      \(candidate.id),
      \(candidate.workspaceID),
      \(candidate.workspacePersonaID),
      \(candidate.personaTemplateID),
      \(candidate.sourceType.rawValue),
      \(candidate.sourceID),
      \(candidate.proposedScope.rawValue),
      \(candidate.title),
      \(candidate.body),
      \(candidate.confidence),
      \(candidate.status.rawValue),
      \(candidate.createdAt),
      \(candidate.reviewedAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      workspace_id = EXCLUDED.workspace_id,
      workspace_persona_id = EXCLUDED.workspace_persona_id,
      persona_template_id = EXCLUDED.persona_template_id,
      source_type = EXCLUDED.source_type,
      source_id = EXCLUDED.source_id,
      proposed_scope = EXCLUDED.proposed_scope,
      title = EXCLUDED.title,
      body = EXCLUDED.body,
      confidence = EXCLUDED.confidence,
      status = EXCLUDED.status,
      reviewed_at = EXCLUDED.reviewed_at
    """
  }

  public func insertMemoryReviewQuery(
    _ review: OrbitMemoryReviewRecord
  ) -> PostgresQuery {
    """
    INSERT INTO memory_review (
      id, memory_candidate_id, reviewer_type, reviewer_id, decision, notes,
      created_at
    ) VALUES (
      \(review.id),
      \(review.memoryCandidateID),
      \(review.reviewerType.rawValue),
      \(review.reviewerID),
      \(review.decision.rawValue),
      \(review.notes),
      \(review.createdAt)
    )
    ON CONFLICT (id) DO NOTHING
    """
  }

  public func upsertMemoryEntryQuery(
    _ entry: OrbitMemoryEntryRecord
  ) -> PostgresQuery {
    """
    INSERT INTO memory_entry (
      id, scope, workspace_id, workspace_persona_id, persona_template_id, title,
      body, status, valid_from, valid_to, source_memory_candidate_id, created_at
    ) VALUES (
      \(entry.id),
      \(entry.scope.rawValue),
      \(entry.workspaceID),
      \(entry.workspacePersonaID),
      \(entry.personaTemplateID),
      \(entry.title),
      \(entry.body),
      \(entry.status.rawValue),
      \(entry.validFrom),
      \(entry.validTo),
      \(entry.sourceMemoryCandidateID),
      \(entry.createdAt)
    )
    ON CONFLICT (id) DO UPDATE SET
      scope = EXCLUDED.scope,
      workspace_id = EXCLUDED.workspace_id,
      workspace_persona_id = EXCLUDED.workspace_persona_id,
      persona_template_id = EXCLUDED.persona_template_id,
      title = EXCLUDED.title,
      body = EXCLUDED.body,
      status = EXCLUDED.status,
      valid_from = EXCLUDED.valid_from,
      valid_to = EXCLUDED.valid_to,
      source_memory_candidate_id = EXCLUDED.source_memory_candidate_id
    """
  }

  public func upsertPersonaGlobalMemoryProfileQuery(
    _ profile: OrbitPersonaGlobalMemoryProfileRecord
  ) -> PostgresQuery {
    """
    INSERT INTO persona_global_memory_profile (
      id, persona_template_id, summary, last_curated_at, created_at
    ) VALUES (
      \(profile.id),
      \(profile.personaTemplateID),
      \(profile.summary),
      \(profile.lastCuratedAt),
      \(profile.createdAt)
    )
    ON CONFLICT (persona_template_id) DO UPDATE SET
      summary = EXCLUDED.summary,
      last_curated_at = EXCLUDED.last_curated_at
    """
  }

  public func selectMemoryCandidateQuery(
    id: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      workspace_id,
      workspace_persona_id,
      persona_template_id,
      source_type,
      source_id,
      proposed_scope,
      title,
      body,
      confidence,
      status,
      created_at,
      reviewed_at
    FROM memory_candidate
    WHERE id = \(id)
    LIMIT 1
    """
  }

  public func selectMemoryReviewsQuery(
    memoryCandidateID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      memory_candidate_id,
      reviewer_type,
      reviewer_id,
      decision,
      notes,
      created_at
    FROM memory_review
    WHERE memory_candidate_id = \(memoryCandidateID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectMemoryEntryQuery(
    id: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      scope,
      workspace_id,
      workspace_persona_id,
      persona_template_id,
      title,
      body,
      status,
      valid_from,
      valid_to,
      source_memory_candidate_id,
      created_at
    FROM memory_entry
    WHERE id = \(id)
    LIMIT 1
    """
  }

  public func selectEligibleApprovedMemoryEntriesQuery(
    workspaceID: UUID,
    workspacePersonaID: UUID,
    personaTemplateID: String
  ) -> PostgresQuery {
    """
    SELECT
      id,
      scope,
      workspace_id,
      workspace_persona_id,
      persona_template_id,
      title,
      body,
      status,
      valid_from,
      valid_to,
      source_memory_candidate_id,
      created_at
    FROM memory_entry
    WHERE status = 'active'
      AND (
        (scope = 'workspace' AND workspace_id = \(workspaceID))
        OR (
          scope = 'workspace_persona'
            AND workspace_id = \(workspaceID)
            AND workspace_persona_id = \(workspacePersonaID)
        )
        OR (
          scope = 'persona_global'
            AND persona_template_id = \(personaTemplateID)
        )
      )
    ORDER BY
      CASE
        WHEN scope = 'workspace' THEN 0
        WHEN scope = 'workspace_persona' THEN 1
        WHEN scope = 'persona_global' THEN 2
        ELSE 99
      END ASC,
      valid_from ASC,
      created_at ASC,
      id ASC
    """
  }

  public func selectPersonaGlobalMemoryProfileQuery(
    personaTemplateID: String
  ) -> PostgresQuery {
    """
    SELECT
      id,
      persona_template_id,
      summary,
      last_curated_at,
      created_at
    FROM persona_global_memory_profile
    WHERE persona_template_id = \(personaTemplateID)
    LIMIT 1
    """
  }

  public func selectRoomSnapshotQuery(
    workspaceSlug: String,
    channelSlug: String,
    postID: UUID? = nil
  ) -> PostgresQuery {
    if let postID {
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
        AND post.id = \(postID)
      ORDER BY thread.created_at ASC
      LIMIT 1
      """
    } else {
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
  }

  public func selectMeetingRoomContextQuery(
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
      channel.workspace_id AS channel_workspace_id,
      channel.slug AS channel_slug,
      channel.name AS channel_name,
      channel.purpose AS channel_purpose,
      channel.status AS channel_status,
      channel.created_at AS channel_created_at,
      channel.archived_at AS channel_archived_at
    FROM workspace
    JOIN channel ON channel.workspace_id = workspace.id
    WHERE workspace.slug = \(workspaceSlug)
      AND channel.slug = \(channelSlug)
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
    postID: UUID? = nil,
    after cursor: OrbitPhase1ReplayCursor?
  ) -> PostgresQuery {
    if let cursor,
      let lastEventCreatedAt = cursor.lastEventCreatedAt,
      let lastEventID = cursor.lastEventID
    {
      if let postID {
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
            AND post_id = \(postID)
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
          AND (
            created_at > \(lastEventCreatedAt)
            OR (created_at = \(lastEventCreatedAt) AND id > \(lastEventID))
          )
        ORDER BY created_at ASC, id ASC
        """
    }

    if let postID {
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
          AND post_id = \(postID)
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

  public func selectNotesQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      note_type,
      body,
      created_by_participant_type,
      created_by_participant_id,
      created_at
    FROM note
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectStructuredAttachmentsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      origin_post_id,
      structured_object_type,
      structured_object_id,
      attachment_ordinal,
      attached_at
    FROM structured_attachment
    WHERE origin_post_id = \(postID)
    ORDER BY attachment_ordinal ASC, attached_at ASC, structured_object_id ASC
    """
  }

  public func selectDecisionsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      title,
      body,
      decision_state,
      rationale,
      tradeoffs,
      dissent,
      linked_reference_ids,
      rationale_note_id,
      created_by_participant_type,
      created_by_participant_id,
      created_at
    FROM decision
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectReferencesQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      reference_type,
      target,
      title,
      created_by_participant_type,
      created_by_participant_id,
      created_at
    FROM reference
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectArtifactsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      artifact_type,
      storage_ref,
      title,
      created_by_participant_type,
      created_by_participant_id,
      created_at
    FROM artifact
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectMeetingOutputStateQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      post_id,
      outcome_state,
      detail,
      recorded_by_participant_type,
      recorded_by_participant_id,
      recorded_at
    FROM meeting_output_state
    WHERE post_id = \(postID)
    """
  }

  public func selectMeetingStateForUpdateQuery(
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
    FOR UPDATE
    """
  }

  public func selectMeetingOpenQuestionsQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      post_id,
      body,
      created_by_participant_type,
      created_by_participant_id,
      created_at
    FROM meeting_open_question
    WHERE post_id = \(postID)
    ORDER BY created_at ASC, id ASC
    """
  }

  public func selectPostLinksQuery(
    postID: UUID
  ) -> PostgresQuery {
    """
    SELECT
      id,
      from_post_id,
      to_post_id,
      link_type,
      created_at
    FROM post_link
    WHERE from_post_id = \(postID)
      OR to_post_id = \(postID)
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

private extension Array where Element == UUID {
  var jsonString: String {
    let values = map(\.uuidString)
    let data = try! JSONEncoder().encode(values)
    return String(decoding: data, as: UTF8.self)
  }
}
