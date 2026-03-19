import Foundation

public enum OrbitPhase1Table: String, CaseIterable, Sendable {
  case workspace
  case channel
  case workspacePersona = "workspace_persona"
  case post
  case thread
  case message
  case postParticipant = "post_participant"
  case postEvent = "post_event"
  case postLink = "post_link"
  case personaActivation = "persona_activation"
  case agentRun = "agent_run"
}

public enum OrbitPhase1EventCategory: String, CaseIterable, Sendable {
  case postCreated = "post.created"
  case messageCreated = "message.created"
  case threadActivityUpdated = "thread.activity.updated"
  case participantJoined = "participant.joined"
  case participantFailed = "participant.failed"
  case activationResolved = "activation.resolved"
  case activationFailed = "activation.failed"
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
  ]

  public static var tableNames: [String] {
    statements.map { $0.table.rawValue }
  }

  public static var bootstrapSQL: String {
    statements.map { $0.sql }.joined(separator: "\n\n")
  }

  public static var initialRealtimeEventCategories: [String] {
    OrbitPhase1EventCategory.allCases.map { $0.rawValue }
  }
}
