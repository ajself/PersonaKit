import PostgresNIO
import Testing

@testable import OrbitServerRuntime

actor RecordingExecutor: OrbitPostgresStatementExecutor {
  private var recordedQueries = [PostgresQuery]()

  func execute(query: PostgresQuery) async throws {
    recordedQueries.append(query)
  }

  func queries() -> [PostgresQuery] {
    recordedQueries
  }
}

struct Phase1RuntimeSchemaTests {
  @Test
  func phase1SchemaIncludesMinimumCanonicalTables() {
    #expect(
      OrbitPhase1RuntimeSchema.tableNames == [
        "workspace",
        "channel",
        "workspace_persona",
        "team",
        "squad",
        "workspace_persona_membership",
        "post",
        "thread",
        "message",
        "realtime_event",
        "post_participant",
        "post_event",
        "post_link",
        "structured_attachment",
        "note",
        "decision",
        "reference",
        "artifact",
        "meeting_output_state",
        "meeting_open_question",
        "meeting_state",
        "meeting_member",
        "persona_activation",
        "agent_run",
        "memory_candidate",
        "memory_review",
        "memory_entry",
        "persona_global_memory_profile",
      ]
    )
  }

  @Test
  func phase1SchemaExcludesAuthoredTruthTables() {
    let canonicalTableNames = Set(OrbitPhase1RuntimeSchema.tableNames)

    for forbiddenTable in OrbitPhase1RuntimeSchema.prohibitedAuthoredTruthTables {
      #expect(canonicalTableNames.contains(forbiddenTable) == false)
    }
  }

  @Test
  func everyCanonicalTableHasACreateStatement() {
    for tableName in OrbitPhase1RuntimeSchema.tableNames {
      #expect(
        OrbitPhase1RuntimeSchema.statements.contains { statement in
          statement.sql.contains("CREATE TABLE IF NOT EXISTS \(tableName)")
        }
      )
    }
  }

  @Test
  func initialRealtimeEventCategoriesIncludeMeetingPromotionVisibilityEvents() {
    #expect(
      OrbitPhase1RuntimeSchema.initialRealtimeEventCategories == [
        "post.created",
        "message.created",
        "thread.activity.updated",
        "participant.joined",
        "participant.failed",
        "activation.resolved",
        "activation.failed",
        "meeting.promotion.attempted",
        "meeting.promotion.failed",
        "meeting.output.committed",
      ]
    )
  }

  @Test
  func migratorExecutesCanonicalStatementsInOrder() async throws {
    let executor = RecordingExecutor()
    let migrator = OrbitPhase1RuntimeMigrator()

    try await migrator.apply(using: executor)

    let recordedQueries = await executor.queries()

    #expect(recordedQueries.map { $0.sql } == OrbitPhase1RuntimeSchema.statements.map { $0.sql })
    #expect(recordedQueries.allSatisfy { $0.binds.count == 0 })
  }

  @Test
  func postgresConfigurationRetainsApprovedDefaults() {
    let configuration = OrbitPostgresConfiguration(
      host: "localhost",
      username: "orbit",
      password: "secret",
      database: "orbit_runtime"
    )

    #expect(configuration.port == 5432)
    #expect(configuration.tls == .disable)
    #expect(configuration.host == "localhost")
    #expect(configuration.database == "orbit_runtime")
  }
}
