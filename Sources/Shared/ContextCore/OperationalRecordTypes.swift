import Foundation

/// Canonical backend type for an operational record resource.
public enum OperationalRecordBackend: String, CaseIterable, Sendable {
  case jsonl
}

/// Stable logical resource identifiers for operational records.
public enum OperationalRecordResourceID: String, CaseIterable, Sendable {
  case partnerContext = "partner-context"
  case partnerHandoffs = "partner-handoffs"
  case gitHistoryGardener = "git-history-gardener"
  case gitHistoryProposals = "git-history-proposals"
  case gardeningEvents = "gardening-events"
}

/// Storage definition for one logical operational record resource.
public struct OperationalRecordResource: Equatable, Sendable {
  public let id: OperationalRecordResourceID
  public let backend: OperationalRecordBackend
  public let canonicalRelativePath: String
  public let schemaRelativePath: String?
  public let projectionRelativePath: String?

  public init(
    id: OperationalRecordResourceID,
    backend: OperationalRecordBackend,
    canonicalRelativePath: String,
    schemaRelativePath: String?,
    projectionRelativePath: String?
  ) {
    self.id = id
    self.backend = backend
    self.canonicalRelativePath = canonicalRelativePath
    self.schemaRelativePath = schemaRelativePath
    self.projectionRelativePath = projectionRelativePath
  }
}

/// Output payload for one-time markdown-to-JSONL migration.
public struct OperationalRecordMigrationOutput: Equatable, Sendable {
  public let files: [String: String]

  public init(files: [String: String]) {
    self.files = files
  }
}

/// Output payload for generated markdown companion docs.
public struct OperationalRecordDocsOutput: Equatable, Sendable {
  public let files: [String: String]

  public init(files: [String: String]) {
    self.files = files
  }
}

/// Errors produced by operational-record migration or rendering.
public enum OperationalRecordError: LocalizedError, Equatable {
  case missingDocument(String)
  case invalidMarkdownTable(String)
  case invalidJSONL(String)
  case bootstrapOnlyImport(String)

  public var errorDescription: String? {
    switch self {
    case .missingDocument(let path):
      return "Missing expected operational record document: \(path)"
    case .invalidMarkdownTable(let message):
      return message
    case .invalidJSONL(let message):
      return message
    case .bootstrapOnlyImport(let message):
      return message
    }
  }
}
