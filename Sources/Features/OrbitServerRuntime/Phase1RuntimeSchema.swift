import Foundation

public enum OrbitPhase1Table: String, CaseIterable, Sendable {
  case workspace
  case channel
  case workspacePersona = "workspace_persona"
  case team
  case squad
  case workspacePersonaMembership = "workspace_persona_membership"
  case post
  case thread
  case message
  case realtimeEvent = "realtime_event"
  case postParticipant = "post_participant"
  case postEvent = "post_event"
  case postLink = "post_link"
  case structuredAttachment = "structured_attachment"
  case note
  case decision
  case reference
  case artifact
  case meetingOutputState = "meeting_output_state"
  case meetingOpenQuestion = "meeting_open_question"
  case meetingState = "meeting_state"
  case meetingMember = "meeting_member"
  case personaActivation = "persona_activation"
  case agentRun = "agent_run"
  case memoryCandidate = "memory_candidate"
  case memoryReview = "memory_review"
  case memoryEntry = "memory_entry"
  case personaGlobalMemoryProfile = "persona_global_memory_profile"
}

public enum OrbitPhase1EventCategory: String, CaseIterable, Sendable {
  case postCreated = "post.created"
  case messageCreated = "message.created"
  case threadActivityUpdated = "thread.activity.updated"
  case participantJoined = "participant.joined"
  case participantFailed = "participant.failed"
  case activationResolved = "activation.resolved"
  case activationFailed = "activation.failed"
  case meetingPromotionAttempted = "meeting.promotion.attempted"
  case meetingPromotionFailed = "meeting.promotion.failed"
  case meetingOutputCommitted = "meeting.output.committed"
}

public struct OrbitPhase1SchemaStatement: Equatable, Sendable {
  public let table: OrbitPhase1Table
  public let sql: String

  public init(
    table: OrbitPhase1Table,
    sql: String
  ) {
    self.table = table
    self.sql = sql
  }
}

public enum OrbitPhase1RuntimeSchema {
  public static let prohibitedAuthoredTruthTables = [
    "persona",
    "directive",
    "kit",
    "skill",
    "session",
  ]

  public static let statements = [
    OrbitPhase1SchemaStatement(
      table: .workspace,
      sql: """
        CREATE TABLE IF NOT EXISTS workspace (
          id UUID PRIMARY KEY,
          slug TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          archived_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .channel,
      sql: """
        CREATE TABLE IF NOT EXISTS channel (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          slug TEXT NOT NULL,
          name TEXT NOT NULL,
          purpose TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          archived_at TIMESTAMPTZ,
          UNIQUE(workspace_id, slug)
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .workspacePersona,
      sql: """
        CREATE TABLE IF NOT EXISTS workspace_persona (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          persona_template_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          default_directive_override_id TEXT,
          status TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          archived_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .team,
      sql: """
        CREATE TABLE IF NOT EXISTS team (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          slug TEXT NOT NULL,
          name TEXT NOT NULL,
          purpose TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          UNIQUE(workspace_id, slug)
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .squad,
      sql: """
        CREATE TABLE IF NOT EXISTS squad (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          team_id UUID REFERENCES team(id),
          slug TEXT NOT NULL,
          name TEXT NOT NULL,
          purpose TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          UNIQUE(workspace_id, slug)
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .workspacePersonaMembership,
      sql: """
        CREATE TABLE IF NOT EXISTS workspace_persona_membership (
          id UUID PRIMARY KEY,
          workspace_persona_id UUID NOT NULL REFERENCES workspace_persona(id),
          team_id UUID REFERENCES team(id),
          squad_id UUID REFERENCES squad(id),
          role_in_group TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          CHECK (
            (team_id IS NOT NULL AND squad_id IS NULL)
            OR (team_id IS NULL AND squad_id IS NOT NULL)
          )
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .post,
      sql: """
        CREATE TABLE IF NOT EXISTS post (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          channel_id UUID NOT NULL REFERENCES channel(id),
          post_type TEXT NOT NULL,
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          title TEXT,
          status TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          archived_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .thread,
      sql: """
        CREATE TABLE IF NOT EXISTS thread (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL UNIQUE REFERENCES post(id),
          status TEXT NOT NULL,
          last_activity_at TIMESTAMPTZ NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          closed_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .message,
      sql: """
        CREATE TABLE IF NOT EXISTS message (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          thread_id UUID NOT NULL REFERENCES thread(id),
          author_type TEXT NOT NULL,
          author_id TEXT NOT NULL,
          reply_to_message_id UUID REFERENCES message(id),
          body TEXT NOT NULL,
          message_format TEXT NOT NULL,
          state TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .realtimeEvent,
      sql: """
        CREATE TABLE IF NOT EXISTS realtime_event (
          id UUID PRIMARY KEY,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          post_id UUID REFERENCES post(id),
          thread_id UUID REFERENCES thread(id),
          category TEXT NOT NULL,
          payload JSONB NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .postParticipant,
      sql: """
        CREATE TABLE IF NOT EXISTS post_participant (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          participant_type TEXT NOT NULL,
          participant_id TEXT NOT NULL,
          joined_at TIMESTAMPTZ NOT NULL,
          left_at TIMESTAMPTZ,
          participation_mode TEXT NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .postEvent,
      sql: """
        CREATE TABLE IF NOT EXISTS post_event (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          thread_id UUID REFERENCES thread(id),
          event_type TEXT NOT NULL,
          payload JSONB NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .postLink,
      sql: """
        CREATE TABLE IF NOT EXISTS post_link (
          id UUID PRIMARY KEY,
          from_post_id UUID NOT NULL REFERENCES post(id),
          to_post_id UUID NOT NULL REFERENCES post(id),
          link_type TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .structuredAttachment,
      sql: """
        CREATE TABLE IF NOT EXISTS structured_attachment (
          origin_post_id UUID NOT NULL REFERENCES post(id),
          structured_object_type TEXT NOT NULL,
          structured_object_id UUID NOT NULL,
          attachment_ordinal INTEGER NOT NULL CHECK (attachment_ordinal >= 0),
          attached_at TIMESTAMPTZ NOT NULL,
          PRIMARY KEY (structured_object_type, structured_object_id),
          UNIQUE(origin_post_id, attachment_ordinal)
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .note,
      sql: """
        CREATE TABLE IF NOT EXISTS note (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          note_type TEXT NOT NULL,
          body TEXT NOT NULL,
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        CREATE TABLE IF NOT EXISTS decision (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          decision_state TEXT NOT NULL,
          rationale TEXT NOT NULL,
          tradeoffs TEXT NOT NULL,
          dissent TEXT NOT NULL,
          linked_reference_ids JSONB NOT NULL,
          rationale_note_id UUID REFERENCES note(id),
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        CREATE TABLE IF NOT EXISTS reference (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          reference_type TEXT NOT NULL,
          target TEXT NOT NULL,
          title TEXT,
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .artifact,
      sql: """
        CREATE TABLE IF NOT EXISTS artifact (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          artifact_type TEXT NOT NULL,
          storage_ref TEXT NOT NULL,
          title TEXT,
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS rationale TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS tradeoffs TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS dissent TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS linked_reference_ids JSONB
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS created_by_participant_type TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ADD COLUMN IF NOT EXISTS created_by_participant_id TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET rationale = 'none recorded'
        WHERE rationale IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET tradeoffs = 'none recorded'
        WHERE tradeoffs IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET dissent = 'none recorded'
        WHERE dissent IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        WITH reference_groups AS (
          SELECT
            post_id,
            COALESCE(
              jsonb_agg(id ORDER BY created_at ASC, id ASC),
              '[]'::jsonb
            ) AS linked_reference_ids
          FROM reference
          GROUP BY post_id
        )
        UPDATE decision
        SET linked_reference_ids = reference_groups.linked_reference_ids
        FROM reference_groups
        WHERE decision.post_id = reference_groups.post_id
          AND decision.linked_reference_ids IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET linked_reference_ids = '[]'::jsonb
        WHERE linked_reference_ids IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET
          created_by_participant_type = post.created_by_participant_type,
          created_by_participant_id = post.created_by_participant_id
        FROM post
        WHERE decision.post_id = post.id
          AND (
            decision.created_by_participant_type IS NULL
            OR decision.created_by_participant_id IS NULL
          )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET created_by_participant_type = 'system'
        WHERE created_by_participant_type IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        UPDATE decision
        SET created_by_participant_id = 'orbit-system'
        WHERE created_by_participant_id IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN rationale SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN tradeoffs SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN dissent SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN linked_reference_ids SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN created_by_participant_type SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .decision,
      sql: """
        ALTER TABLE IF EXISTS decision
        ALTER COLUMN created_by_participant_id SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        ALTER TABLE IF EXISTS reference
        ADD COLUMN IF NOT EXISTS created_by_participant_type TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        ALTER TABLE IF EXISTS reference
        ADD COLUMN IF NOT EXISTS created_by_participant_id TEXT
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        UPDATE reference
        SET
          created_by_participant_type = post.created_by_participant_type,
          created_by_participant_id = post.created_by_participant_id
        FROM post
        WHERE reference.post_id = post.id
          AND (
            reference.created_by_participant_type IS NULL
            OR reference.created_by_participant_id IS NULL
          )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        UPDATE reference
        SET created_by_participant_type = 'system'
        WHERE created_by_participant_type IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        UPDATE reference
        SET created_by_participant_id = 'orbit-system'
        WHERE created_by_participant_id IS NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        ALTER TABLE IF EXISTS reference
        ALTER COLUMN created_by_participant_type SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .reference,
      sql: """
        ALTER TABLE IF EXISTS reference
        ALTER COLUMN created_by_participant_id SET NOT NULL
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .structuredAttachment,
      sql: """
        INSERT INTO structured_attachment (
          origin_post_id,
          structured_object_type,
          structured_object_id,
          attachment_ordinal,
          attached_at
        )
        SELECT
          origin_post_id,
          structured_object_type,
          structured_object_id,
          ROW_NUMBER() OVER (
            PARTITION BY origin_post_id
            ORDER BY attached_at ASC, structured_object_type ASC, structured_object_id ASC
          ) - 1,
          attached_at
        FROM (
          SELECT
            post_id AS origin_post_id,
            'note' AS structured_object_type,
            id AS structured_object_id,
            created_at AS attached_at
          FROM note
          UNION ALL
          SELECT
            post_id AS origin_post_id,
            'decision' AS structured_object_type,
            id AS structured_object_id,
            created_at AS attached_at
          FROM decision
          UNION ALL
          SELECT
            post_id AS origin_post_id,
            'reference' AS structured_object_type,
            id AS structured_object_id,
            created_at AS attached_at
          FROM reference
          UNION ALL
          SELECT
            post_id AS origin_post_id,
            'artifact' AS structured_object_type,
            id AS structured_object_id,
            created_at AS attached_at
          FROM artifact
        ) AS structured_objects
        ON CONFLICT (structured_object_type, structured_object_id) DO NOTHING
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .meetingOutputState,
      sql: """
        CREATE TABLE IF NOT EXISTS meeting_output_state (
          post_id UUID PRIMARY KEY REFERENCES post(id),
          outcome_state TEXT NOT NULL,
          detail TEXT,
          recorded_by_participant_type TEXT NOT NULL,
          recorded_by_participant_id TEXT NOT NULL,
          recorded_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .meetingOpenQuestion,
      sql: """
        CREATE TABLE IF NOT EXISTS meeting_open_question (
          id UUID PRIMARY KEY,
          post_id UUID NOT NULL REFERENCES post(id),
          body TEXT NOT NULL,
          created_by_participant_type TEXT NOT NULL,
          created_by_participant_id TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .meetingState,
      sql: """
        CREATE TABLE IF NOT EXISTS meeting_state (
          post_id UUID PRIMARY KEY REFERENCES post(id),
          meeting_type TEXT NOT NULL,
          status TEXT NOT NULL,
          started_by_participant_type TEXT NOT NULL,
          started_by_participant_id TEXT NOT NULL,
          started_at TIMESTAMPTZ NOT NULL,
          completed_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .meetingMember,
      sql: """
        CREATE TABLE IF NOT EXISTS meeting_member (
          id UUID PRIMARY KEY,
          meeting_post_id UUID NOT NULL REFERENCES post(id),
          post_participant_id UUID NOT NULL REFERENCES post_participant(id),
          participation_role TEXT NOT NULL,
          selected_reason TEXT NOT NULL,
          joined_at TIMESTAMPTZ NOT NULL,
          completed_at TIMESTAMPTZ,
          UNIQUE(meeting_post_id, post_participant_id)
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .personaActivation,
      sql: """
        CREATE TABLE IF NOT EXISTS persona_activation (
          id UUID PRIMARY KEY,
          initiated_by_participant_type TEXT NOT NULL,
          initiated_by_participant_id TEXT NOT NULL,
          workspace_id UUID NOT NULL REFERENCES workspace(id),
          channel_id UUID REFERENCES channel(id),
          origin_post_id UUID NOT NULL REFERENCES post(id),
          origin_thread_id UUID NOT NULL REFERENCES thread(id),
          trigger_message_id UUID NOT NULL REFERENCES message(id),
          addressed_target_kind TEXT NOT NULL,
          addressed_target_reference_id TEXT NOT NULL,
          resolved_workspace_persona_instance_id UUID NOT NULL REFERENCES workspace_persona(id),
          response_mode TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .agentRun,
      sql: """
        CREATE TABLE IF NOT EXISTS agent_run (
          id UUID PRIMARY KEY,
          persona_activation_id UUID NOT NULL REFERENCES persona_activation(id),
          runner_kind TEXT NOT NULL,
          status TEXT NOT NULL,
          started_at TIMESTAMPTZ NOT NULL,
          completed_at TIMESTAMPTZ,
          failure_reason TEXT
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .memoryCandidate,
      sql: """
        CREATE TABLE IF NOT EXISTS memory_candidate (
          id UUID PRIMARY KEY,
          workspace_id UUID REFERENCES workspace(id),
          workspace_persona_id UUID REFERENCES workspace_persona(id),
          persona_template_id TEXT,
          source_type TEXT NOT NULL,
          source_id TEXT NOT NULL,
          proposed_scope TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          confidence DOUBLE PRECISION NOT NULL,
          status TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL,
          reviewed_at TIMESTAMPTZ
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .memoryReview,
      sql: """
        CREATE TABLE IF NOT EXISTS memory_review (
          id UUID PRIMARY KEY,
          memory_candidate_id UUID NOT NULL REFERENCES memory_candidate(id),
          reviewer_type TEXT NOT NULL,
          reviewer_id TEXT NOT NULL,
          decision TEXT NOT NULL,
          notes TEXT,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .memoryEntry,
      sql: """
        CREATE TABLE IF NOT EXISTS memory_entry (
          id UUID PRIMARY KEY,
          scope TEXT NOT NULL,
          workspace_id UUID REFERENCES workspace(id),
          workspace_persona_id UUID REFERENCES workspace_persona(id),
          persona_template_id TEXT,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          status TEXT NOT NULL,
          valid_from TIMESTAMPTZ NOT NULL,
          valid_to TIMESTAMPTZ,
          source_memory_candidate_id UUID REFERENCES memory_candidate(id),
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
    OrbitPhase1SchemaStatement(
      table: .personaGlobalMemoryProfile,
      sql: """
        CREATE TABLE IF NOT EXISTS persona_global_memory_profile (
          id UUID PRIMARY KEY,
          persona_template_id TEXT NOT NULL UNIQUE,
          summary TEXT NOT NULL,
          last_curated_at TIMESTAMPTZ NOT NULL,
          created_at TIMESTAMPTZ NOT NULL
        )
        """
    ),
  ]

  public static var tableNames: [String] {
    var seen = Set<String>()

    return statements.compactMap { statement in
      let tableName = statement.table.rawValue
      let inserted = seen.insert(tableName).inserted
      return inserted ? tableName : nil
    }
  }

  public static var bootstrapSQL: String {
    statements.map { $0.sql }.joined(separator: "\n\n")
  }

  public static var initialRealtimeEventCategories: [String] {
    OrbitPhase1EventCategory.allCases.map { $0.rawValue }
  }
}
