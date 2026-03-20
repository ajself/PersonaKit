import Foundation

/// Shared builder for operational-record migration and generated projections.
public enum OperationalRecordBuilder {
  public static let partnerContextEventsRelativePath = "Docs/PersonaKit/Development/logs/partner-context-events.jsonl"
  public static let partnerContextSchemaRelativePath =
    "Docs/PersonaKit/Development/logs/partner-context-events.schema.json"
  public static let partnerContextProjectionRelativePath = "Docs/PersonaKit/Development/partner-context-log.md"

  public static let partnerHandoffsRelativePath = "Docs/PersonaKit/Development/logs/partner-handoffs.jsonl"
  public static let partnerHandoffsSchemaRelativePath = "Docs/PersonaKit/Development/logs/partner-handoffs.schema.json"
  public static let partnerHandoffsProjectionRelativePath = "Docs/PersonaKit/Development/partner-handoff-register.md"

  public static let gitHistoryGardenerRelativePath = "Docs/PersonaKit/Development/logs/git-history-gardener.jsonl"
  public static let gitHistoryGardenerProjectionRelativePath = "Docs/PersonaKit/Development/git-history-gardener-log.md"

  public static let gitHistoryProposalsRelativePath =
    "Docs/PersonaKit/Development/logs/git-history-gardener-proposals.jsonl"
  public static let gitHistoryProposalsSchemaRelativePath =
    "Docs/PersonaKit/Development/logs/git-history-gardener-proposals.schema.json"
  public static let gitHistoryProposalsProjectionRelativePath =
    "Docs/PersonaKit/Development/git-history-gardener-proposals.md"

  public static let gardeningEventsRelativePath = "Docs/PersonaKit/Development/logs/gardening-events.jsonl"
  public static let packGardenerProjectionRelativePath = "Docs/PersonaKit/Development/pack-gardener-log.md"

  public static let allResources: [OperationalRecordResource] = [
    .init(
      id: .partnerContext,
      backend: .jsonl,
      canonicalRelativePath: partnerContextEventsRelativePath,
      schemaRelativePath: partnerContextSchemaRelativePath,
      projectionRelativePath: partnerContextProjectionRelativePath
    ),
    .init(
      id: .partnerHandoffs,
      backend: .jsonl,
      canonicalRelativePath: partnerHandoffsRelativePath,
      schemaRelativePath: partnerHandoffsSchemaRelativePath,
      projectionRelativePath: partnerHandoffsProjectionRelativePath
    ),
    .init(
      id: .gitHistoryGardener,
      backend: .jsonl,
      canonicalRelativePath: gitHistoryGardenerRelativePath,
      schemaRelativePath: nil,
      projectionRelativePath: gitHistoryGardenerProjectionRelativePath
    ),
    .init(
      id: .gitHistoryProposals,
      backend: .jsonl,
      canonicalRelativePath: gitHistoryProposalsRelativePath,
      schemaRelativePath: gitHistoryProposalsSchemaRelativePath,
      projectionRelativePath: gitHistoryProposalsProjectionRelativePath
    ),
    .init(
      id: .gardeningEvents,
      backend: .jsonl,
      canonicalRelativePath: gardeningEventsRelativePath,
      schemaRelativePath: nil,
      projectionRelativePath: packGardenerProjectionRelativePath
    ),
  ]

  /// Builds deterministic JSONL files by importing markdown ledgers.
  public static func buildMigrationOutput(
    root: URL
  ) throws -> OperationalRecordMigrationOutput {
    try OperationalRecordMigrationSupport.buildMigrationOutput(root: root)
  }

  /// Builds generated markdown companion docs from canonical JSONL resources.
  public static func buildDocsOutput(
    root: URL
  ) throws -> OperationalRecordDocsOutput {
    try OperationalRecordRenderingSupport.buildDocsOutput(root: root)
  }
}
