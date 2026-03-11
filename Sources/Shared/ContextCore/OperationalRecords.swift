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
    let projectRoot = root.deletingLastPathComponent()
    let partnerContextDocument = try readDocument(
      relativePath: partnerContextProjectionRelativePath,
      projectRoot: projectRoot
    )
    let partnerHandoffDocument = try readDocument(
      relativePath: partnerHandoffsProjectionRelativePath,
      projectRoot: projectRoot
    )
    let gitHistoryProposalsDocument = try readDocument(
      relativePath: gitHistoryProposalsProjectionRelativePath,
      projectRoot: projectRoot
    )
    try assertLegacyImportDocument(
      partnerContextDocument,
      relativePath: partnerContextProjectionRelativePath
    )
    try assertLegacyImportDocument(
      partnerHandoffDocument,
      relativePath: partnerHandoffsProjectionRelativePath
    )
    try assertLegacyImportDocument(
      gitHistoryProposalsDocument,
      relativePath: gitHistoryProposalsProjectionRelativePath
    )
    let gitHistoryEntries = try decodeOptionalJSONLines(
      relativePath: gitHistoryGardenerRelativePath,
      projectRoot: projectRoot,
      as: GitHistoryGardenerEntry.self
    )

    let partnerContextEvents = try parsePartnerContextEvents(
      document: partnerContextDocument
    )
    let partnerHandoffs = try parsePartnerHandoffs(
      document: partnerHandoffDocument
    )
    let gitHistoryProposals = try parseGitHistoryProposalEvents(
      document: gitHistoryProposalsDocument,
      gitHistoryEntries: gitHistoryEntries
    )

    return OperationalRecordMigrationOutput(
      files: [
        partnerContextEventsRelativePath: encodeJSONLines(partnerContextEvents),
        partnerHandoffsRelativePath: encodeJSONLines(partnerHandoffs),
        gitHistoryProposalsRelativePath: encodeJSONLines(gitHistoryProposals),
      ]
    )
  }

  /// Builds generated markdown companion docs from canonical JSONL resources.
  public static func buildDocsOutput(
    root: URL
  ) throws -> OperationalRecordDocsOutput {
    let projectRoot = root.deletingLastPathComponent()
    let partnerContextEvents = try decodeJSONLines(
      relativePath: partnerContextEventsRelativePath,
      projectRoot: projectRoot,
      as: PartnerContextEvent.self
    )
    let partnerHandoffs = try decodeJSONLines(
      relativePath: partnerHandoffsRelativePath,
      projectRoot: projectRoot,
      as: PartnerHandoffEvent.self
    )
    let gardeningEvents = try decodeJSONLines(
      relativePath: gardeningEventsRelativePath,
      projectRoot: projectRoot,
      as: GardeningEventProjection.self
    )
    let gitHistoryEntries = try decodeJSONLines(
      relativePath: gitHistoryGardenerRelativePath,
      projectRoot: projectRoot,
      as: GitHistoryGardenerEntry.self
    )
    let gitHistoryProposals = try decodeJSONLines(
      relativePath: gitHistoryProposalsRelativePath,
      projectRoot: projectRoot,
      as: GitHistoryProposalEvent.self
    )

    return OperationalRecordDocsOutput(
      files: [
        partnerContextProjectionRelativePath: renderPartnerContextLog(
          events: partnerContextEvents
        ),
        partnerHandoffsProjectionRelativePath: renderPartnerHandoffRegister(
          events: partnerHandoffs
        ),
        packGardenerProjectionRelativePath: renderPackGardenerLog(
          events: gardeningEvents
        ),
        gitHistoryGardenerProjectionRelativePath: renderGitHistoryGardenerLog(
          entries: gitHistoryEntries
        ),
        gitHistoryProposalsProjectionRelativePath: renderGitHistoryProposalLog(
          entries: gitHistoryEntries,
          events: gitHistoryProposals
        ),
      ]
    )
  }

  private static func readDocument(
    relativePath: String,
    projectRoot: URL
  ) throws -> String {
    let url = projectRoot.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw OperationalRecordError.missingDocument(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
  }

  private static func assertLegacyImportDocument(
    _ document: String,
    relativePath: String
  ) throws {
    if document.contains("> Generated file. Do not edit manually.") {
      throw OperationalRecordError.bootstrapOnlyImport(
        "migrate-log-records only supports legacy markdown ledgers. "
          + "\(relativePath) is already a generated projection."
      )
    }
  }

  private static func parsePartnerContextEvents(
    document: String
  ) throws -> [PartnerContextEvent] {
    let rows = try parseTableRows(
      document: document,
      requiredColumnCounts: [6],
      dateColumnIndex: 0
    )

    return rows.enumerated().map { index, row in
      PartnerContextEvent(
        entryId: "PCL-\(zeroPad(index + 1, width: 4))",
        date: row[0],
        sessionId: "samwise-partner-sync",
        summary: row[1],
        implications: row[2],
        affectedIds: parseBacktickIDs(from: row[3]),
        nextAction: row[4],
        verification: row[5],
        details: nil
      )
    }
  }

  private static func parsePartnerHandoffs(
    document: String
  ) throws -> [PartnerHandoffEvent] {
    let historyRows = parsePartnerHandoffHistoryRows(document: document)
    if !historyRows.isEmpty {
      return historyRows
    }

    let rows = try parseTableRows(
      document: document,
      requiredColumnCounts: [7, 8],
      dateColumnIndex: 0
    )

    return rows.enumerated().map { index, row in
      let handoffID: String
      let title: String
      let ownerRef: String
      let writeScope: String
      let acceptanceCriteria: String
      let risks: String
      let status: String

      if row.count == 8 {
        handoffID = row[1]
        title = row[2]
        ownerRef = row[3]
        writeScope = row[4]
        acceptanceCriteria = row[5]
        risks = row[6]
        status = row[7]
      } else {
        handoffID = "HOF-\(zeroPad(index + 1, width: 3))"
        title = row[1]
        ownerRef = row[2]
        writeScope = row[3]
        acceptanceCriteria = row[4]
        risks = row[5]
        status = row[6]
      }

      return PartnerHandoffEvent(
        entryId: "PHF-\(zeroPad(index + 1, width: 4))",
        handoffId: handoffID,
        date: row[0],
        sessionId: parseSessionID(from: ownerRef) ?? "samwise-partner-sync",
        title: title,
        ownerRef: ownerRef,
        writeScope: writeScope,
        acceptanceCriteria: acceptanceCriteria,
        risks: risks,
        status: status,
        eventType: "recorded",
        details: nil
      )
    }
  }

  private static func parseGitHistoryProposalEvents(
    document: String,
    gitHistoryEntries: [GitHistoryGardenerEntry]
  ) throws -> [GitHistoryProposalEvent] {
    let historyRows = parseGitHistoryProposalHistoryRows(document: document)
    if !historyRows.isEmpty {
      return historyRows
    }

    let rows = try parseTableRows(
      document: document,
      requiredColumnCounts: [7, 9],
      dateColumnIndex: nil
    )
    return rows.enumerated().map { index, row in
      if row.count == 9 {
        return GitHistoryProposalEvent(
          entryId: "GHL-\(zeroPad(index + 1, width: 4))",
          proposalId: stripBackticks(row[0]),
          date: row[1],
          sessionId: "git-history-gardener",
          analysisPassId: stripBackticks(row[2]),
          candidateCommit: stripAllBackticks(row[3]),
          proposedAction: stripAllBackticks(row[4]),
          rationale: row[5],
          risk: row[6],
          commandPlan: row[7],
          approvalStatus: row[8],
          eventType: inferredProposalEventType(
            approvalStatus: row[8]
          ),
          details: nil
        )
      }

      let candidateCommit = stripAllBackticks(row[1])
      let matchingAnalysisEntry = gitHistoryEntries.first { entry in
        entry.phaseLabel.hasPrefix("analysis-pass-")
          && entry.candidateCommit == candidateCommit
      }
      let fallbackDate =
        matchingAnalysisEntry?.date
        ?? parseFirstCapture(
          pattern: #"Execution Result \(([0-9]{4}-[0-9]{2}-[0-9]{2})\)"#,
          in: document
        )
        ?? parseFirstCapture(
          pattern: #"Last Reviewed:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})"#,
          in: document
        )
        ?? "1970-01-01"
      let fallbackAnalysisPassID =
        matchingAnalysisEntry?.phaseLabel
        ?? "analysis-pass-unknown"

      return GitHistoryProposalEvent(
        entryId: "GHL-\(zeroPad(index + 1, width: 4))",
        proposalId: stripBackticks(row[0]),
        date: fallbackDate,
        sessionId: "git-history-gardener",
        analysisPassId: fallbackAnalysisPassID,
        candidateCommit: candidateCommit,
        proposedAction: stripAllBackticks(row[2]),
        rationale: row[3],
        risk: row[4],
        commandPlan: row[5],
        approvalStatus: normalizeLegacyApprovalStatus(row[6]),
        eventType: inferredProposalEventType(
          approvalStatus: row[6]
        ),
        details: [
          "legacyApprovalStatus": row[6]
        ]
      )
    }
  }

  private static func renderPartnerContextLog(
    events: [PartnerContextEvent]
  ) -> String {
    var lines: [String] = [
      "# Partner Context Log",
      "",
      "> Generated file. Do not edit manually.",
      "> Canonical resource: `partner-context` backed by "
        + "`Docs/PersonaKit/Development/logs/partner-context-events.jsonl`.",
      "",
      "## Entries",
      "",
      "| Date | Update Summary | Implications | Affected IDs | Next Action | Verification |",
      "| --- | --- | --- | --- | --- | --- |",
    ]

    for event in events {
      lines.append(
        "| \(event.date) | \(escapeTableCell(event.summary)) | \(escapeTableCell(event.implications)) | "
          + "\(formatIDList(event.affectedIds)) | \(escapeTableCell(event.nextAction)) | "
          + "\(escapeTableCell(event.verification)) |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderPartnerHandoffRegister(
    events: [PartnerHandoffEvent]
  ) -> String {
    let latestByHandoff = latestEventMap(
      events: events,
      keyPath: \.handoffId
    )
    let ordered = latestByHandoff.values.sorted { lhs, rhs in
      if lhs.handoffId == rhs.handoffId {
        return lhs.entryId < rhs.entryId
      }
      return lhs.handoffId < rhs.handoffId
    }

    var lines: [String] = [
      "# Partner Handoff Register",
      "",
      "> Generated file. Do not edit manually.",
      "> Canonical resource: `partner-handoffs` backed by "
        + "`Docs/PersonaKit/Development/logs/partner-handoffs.jsonl`.",
      "",
      "## Current Handoff State",
      "",
      "| Date | Handoff ID | Handoff | Owner Persona/Session | Write Scope | Acceptance Criteria | Risks | Status |",
      "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]

    for event in ordered {
      lines.append(
        "| \(event.date) | `\(event.handoffId)` | \(escapeTableCell(event.title)) | "
          + "\(escapeTableCell(event.ownerRef)) | \(escapeTableCell(event.writeScope)) | "
          + "\(escapeTableCell(event.acceptanceCriteria)) | \(escapeTableCell(event.risks)) | "
          + "\(escapeTableCell(event.status)) |"
      )
    }

    lines.append("")
    lines.append("## Event History")
    lines.append("")
    lines.append(
      "| Entry ID | Handoff ID | Date | Session ID | Event Type | Handoff | Owner Persona/Session | "
        + "Write Scope | Acceptance Criteria | Risks | Status |"
    )
    lines.append(
      "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    )

    for event in events.sorted(by: \.entryId) {
      lines.append(
        "| `\(event.entryId)` | `\(event.handoffId)` | \(event.date) | `\(event.sessionId)` | "
          + "`\(event.eventType)` | \(escapeTableCell(event.title)) | \(escapeTableCell(event.ownerRef)) | "
          + "\(escapeTableCell(event.writeScope)) | \(escapeTableCell(event.acceptanceCriteria)) | "
          + "\(escapeTableCell(event.risks)) | \(escapeTableCell(event.status)) |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderPackGardenerLog(
    events: [GardeningEventProjection]
  ) -> String {
    let filtered = events.filter { $0.sessionId == "pack-gardener-maintenance" }

    var lines: [String] = [
      "# Pack Gardener Log",
      "",
      "> Generated file. Do not edit manually.",
      "> Canonical resource: `gardening-events` backed by "
        + "`Docs/PersonaKit/Development/logs/gardening-events.jsonl`.",
      "",
      "## Entries",
      "",
      "| Date | Phase | Subject | Decision | Affected Artifacts | Verification |",
      "| --- | --- | --- | --- | --- | --- |",
    ]

    for event in filtered {
      let decision = "`\(event.proposedAction)` / `\(event.decision)`"
      lines.append(
        "| \(event.date) | \(escapeTableCell(event.phaseLabel)) | \(escapeTableCell(event.subject)) | "
          + "\(decision) | \(formatIDList(event.affectedArtifacts)) | "
          + "\(escapeTableCell(event.validationStatus)) |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderGitHistoryGardenerLog(
    entries: [GitHistoryGardenerEntry]
  ) -> String {
    var lines: [String] = [
      "# Git History Gardener Log",
      "",
      "> Generated file. Do not edit manually.",
      "> Canonical resource: `git-history-gardener` backed by "
        + "`Docs/PersonaKit/Development/logs/git-history-gardener.jsonl`.",
      "",
      "## Entries",
      "",
      "| Date | Phase | Commit Range | Candidate Commit | Proposed Action | Decision | Verification |",
      "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for entry in entries {
      lines.append(
        "| \(entry.date) | \(escapeTableCell(entry.phaseLabel)) | `\(entry.commitRange)` | "
          + "`\(entry.candidateCommit)` | `\(entry.proposedAction)` | `\(entry.decision)` | "
          + "`\(entry.validationStatus)` |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderGitHistoryProposalLog(
    entries: [GitHistoryGardenerEntry],
    events: [GitHistoryProposalEvent]
  ) -> String {
    let latestByProposal = latestEventMap(
      events: events,
      keyPath: \.proposalId
    )
    let ordered = latestByProposal.values.sorted { lhs, rhs in
      lhs.proposalId < rhs.proposalId
    }
    let latestAnalysisEntry = latestAnalysisPassEntry(from: entries)
    let currentPassID = latestAnalysisEntry?.phaseLabel
    let currentPendingProposals = ordered.filter { event in
      guard let currentPassID else {
        return false
      }
      return event.analysisPassId == currentPassID && event.approvalStatus == "pending"
    }

    var lines: [String] = [
      "# Git History Gardener Proposals",
      "",
      "> Generated file. Do not edit manually.",
      "> Canonical resource: `git-history-proposals` backed by "
        + "`Docs/PersonaKit/Development/logs/git-history-gardener-proposals.jsonl`.",
      "> Pass-level context remains available in `Docs/PersonaKit/Development/logs/git-history-gardener.jsonl`.",
      "",
      "## Current Analysis Pass",
      "",
      "- Session: `git-history-gardener`",
    ]

    if let latestAnalysisEntry {
      lines.append("- Commit range: `\(latestAnalysisEntry.commitRange)`")
      lines.append("- Mode: analysis only")
      lines.append("- Current analysis pass: `\(latestAnalysisEntry.phaseLabel)`")
    } else {
      lines.append("- Current analysis pass: unavailable")
    }

    lines.append("")
    lines.append("## Proposed Changes (Pending Approval)")
    lines.append("")

    if currentPendingProposals.isEmpty {
      if let currentPassID {
        lines.append("- None in current analysis pass (`\(currentPassID)`).")
      } else {
        lines.append("- None.")
      }
    } else {
      lines.append(
        "| Proposal ID | Latest Date | Analysis Pass | Candidate Commit | Proposed Action | Rationale | Risk | "
          + "Command Plan | Approval Status |"
      )
      lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")

      for event in currentPendingProposals {
        lines.append(
          "| `\(event.proposalId)` | \(event.date) | `\(event.analysisPassId)` | "
            + "`\(event.candidateCommit)` | `\(event.proposedAction)` | "
            + "\(escapeTableCell(event.rationale)) | \(escapeTableCell(event.risk)) | "
            + "\(escapeTableCell(event.commandPlan)) | \(escapeTableCell(event.approvalStatus)) |"
        )
      }
    }

    lines.append("")
    lines.append("## Event History")
    lines.append("")
    lines.append(
      "| Entry ID | Proposal ID | Date | Analysis Pass | Candidate Commit | Proposed Action | Rationale | "
        + "Risk | Command Plan | Approval Status | Event Type |"
    )
    lines.append(
      "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    )

    for event in events.sorted(by: \.entryId) {
      lines.append(
        "| `\(event.entryId)` | `\(event.proposalId)` | \(event.date) | `\(event.analysisPassId)` | "
          + "`\(event.candidateCommit)` | `\(event.proposedAction)` | "
          + "\(escapeTableCell(event.rationale)) | \(escapeTableCell(event.risk)) | "
          + "\(escapeTableCell(event.commandPlan)) | \(escapeTableCell(event.approvalStatus)) | "
          + "`\(event.eventType)` |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func latestAnalysisPassEntry(
    from entries: [GitHistoryGardenerEntry]
  ) -> GitHistoryGardenerEntry? {
    entries
      .filter { $0.phaseLabel.hasPrefix("analysis-pass-") }
      .max { lhs, rhs in
        let lhsNumber = analysisPassNumber(lhs.phaseLabel)
        let rhsNumber = analysisPassNumber(rhs.phaseLabel)
        if lhsNumber == rhsNumber {
          if lhs.date == rhs.date {
            return lhs.entryId < rhs.entryId
          }
          return lhs.date < rhs.date
        }
        return lhsNumber < rhsNumber
      }
  }

  private static func analysisPassNumber(
    _ phaseLabel: String
  ) -> Int {
    let suffix = phaseLabel.split(separator: "-").last
    return suffix.flatMap { Int(String($0)) } ?? 0
  }

  private static func parsePartnerHandoffHistoryRows(
    document: String
  ) -> [PartnerHandoffEvent] {
    parseMarkdownTableRows(document: document).compactMap { columns in
      guard columns.count == 11 else {
        return nil
      }

      guard columns[0] != "Entry ID", isDate(columns[2]) else {
        return nil
      }

      let entryID = stripBackticks(columns[0])
      let handoffID = stripBackticks(columns[1])
      let sessionID = stripBackticks(columns[3])
      let eventType = stripBackticks(columns[4])
      guard !entryID.isEmpty, !handoffID.isEmpty, !sessionID.isEmpty else {
        return nil
      }

      return PartnerHandoffEvent(
        entryId: entryID,
        handoffId: handoffID,
        date: columns[2],
        sessionId: sessionID,
        title: columns[5],
        ownerRef: columns[6],
        writeScope: columns[7],
        acceptanceCriteria: columns[8],
        risks: columns[9],
        status: columns[10],
        eventType: eventType.isEmpty ? "recorded" : eventType,
        details: nil
      )
    }
  }

  private static func parseGitHistoryProposalHistoryRows(
    document: String
  ) -> [GitHistoryProposalEvent] {
    parseMarkdownTableRows(document: document).compactMap { columns in
      guard columns.count == 11 else {
        return nil
      }

      guard columns[0] != "Entry ID", isDate(columns[2]) else {
        return nil
      }

      let entryID = stripBackticks(columns[0])
      let proposalID = stripBackticks(columns[1])
      let analysisPassID = stripBackticks(columns[3])
      let candidateCommit = stripBackticks(columns[4])
      let proposedAction = stripBackticks(columns[5])
      let eventType = stripBackticks(columns[10])
      guard !entryID.isEmpty, !proposalID.isEmpty else {
        return nil
      }

      return GitHistoryProposalEvent(
        entryId: entryID,
        proposalId: proposalID,
        date: columns[2],
        sessionId: "git-history-gardener",
        analysisPassId: analysisPassID,
        candidateCommit: stripAllBackticks(candidateCommit),
        proposedAction: stripAllBackticks(proposedAction),
        rationale: columns[6],
        risk: columns[7],
        commandPlan: columns[8],
        approvalStatus: columns[9],
        eventType: eventType.isEmpty ? inferredProposalEventType(approvalStatus: columns[9]) : eventType,
        details: nil
      )
    }
  }

  private static func parseTableRows(
    document: String,
    requiredColumnCounts: Set<Int>,
    dateColumnIndex: Int?
  ) throws -> [[String]] {
    var rows: [[String]] = []

    for columns in parseMarkdownTableRows(document: document) {
      guard requiredColumnCounts.contains(columns.count) else {
        continue
      }

      if columns.allSatisfy(isTableDividerCell) {
        continue
      }

      if let dateColumnIndex {
        guard columns.indices.contains(dateColumnIndex) else {
          continue
        }
        guard isDate(columns[dateColumnIndex]) else {
          continue
        }
      } else {
        guard columns.indices.contains(0) else {
          continue
        }
        guard columns[0] != "Proposal ID" else {
          continue
        }
      }

      rows.append(columns)
    }

    guard !rows.isEmpty else {
      throw OperationalRecordError.invalidMarkdownTable(
        "Expected at least one parseable markdown table row."
      )
    }

    return rows
  }

  private static func parseMarkdownTableRows(
    document: String
  ) -> [[String]] {
    document.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
      let line = String(rawLine)
      guard line.trimmingCharacters(in: .whitespaces).hasPrefix("|") else {
        return nil
      }

      return splitMarkdownTableRow(line)
    }
  }

  private static func splitMarkdownTableRow(_ row: String) -> [String] {
    var trimmed = row.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") {
      trimmed.removeFirst()
    }
    if trimmed.hasSuffix("|") {
      trimmed.removeLast()
    }

    return trimmed.split(separator: "|", omittingEmptySubsequences: false).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
  }

  private static func isTableDividerCell(_ value: String) -> Bool {
    let normalized = value.replacingOccurrences(of: ":", with: "")
    return !normalized.isEmpty && normalized.allSatisfy { $0 == "-" }
  }

  private static func isDate(_ value: String) -> Bool {
    parseFirstCapture(
      pattern: #"^([0-9]{4}-[0-9]{2}-[0-9]{2})$"#,
      in: value
    ) != nil
  }

  private static func parseBacktickIDs(from value: String) -> [String] {
    let matches = parseAllCaptures(
      pattern: #"`([^`]+)`"#,
      in: value
    )

    if !matches.isEmpty {
      return matches
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return []
    }

    return [trimmed]
  }

  private static func parseSessionID(
    from ownerRef: String
  ) -> String? {
    let matches = parseAllCaptures(
      pattern: #"`([^`]+)`"#,
      in: ownerRef
    )

    if matches.count >= 2 {
      return matches[1]
    }

    let parts = ownerRef.split(separator: "/").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return parts.last?.isEmpty == false ? parts.last : nil
  }

  private static func parseFirstCapture(
    pattern: String,
    in value: String
  ) -> String? {
    guard let regularExpression = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    guard let match = regularExpression.firstMatch(in: value, range: range),
      match.numberOfRanges > 1,
      let captureRange = Range(match.range(at: 1), in: value)
    else {
      return nil
    }

    return String(value[captureRange])
  }

  private static func parseAllCaptures(
    pattern: String,
    in value: String
  ) -> [String] {
    guard let regularExpression = try? NSRegularExpression(pattern: pattern) else {
      return []
    }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regularExpression.matches(in: value, range: range).compactMap { match in
      guard match.numberOfRanges > 1,
        let captureRange = Range(match.range(at: 1), in: value)
      else {
        return nil
      }
      return String(value[captureRange])
    }
  }

  private static func normalizeLegacyApprovalStatus(
    _ value: String
  ) -> String {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    switch normalized {
    case _ where normalized.contains("rejected"):
      return "rejected"
    case _ where normalized.contains("approved"):
      return "approved"
    default:
      return "pending"
    }
  }

  private static func inferredProposalEventType(
    approvalStatus: String
  ) -> String {
    let normalized = approvalStatus.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    if normalized.contains("executed") {
      return "executed"
    }

    if normalized.contains("approved") {
      return "approved"
    }

    if normalized.contains("rejected") {
      return "rejected"
    }

    return "proposed"
  }

  private static func zeroPad(_ value: Int, width: Int) -> String {
    String(format: "%0\(width)d", value)
  }

  private static func stripBackticks(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("`"), trimmed.hasSuffix("`"), trimmed.count >= 2 else {
      return trimmed
    }

    return String(trimmed.dropFirst().dropLast())
  }

  private static func stripAllBackticks(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "`", with: "")
  }

  private static func encodeJSONLines<T: Encodable>(
    _ values: [T]
  ) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let lines = values.map { value in
      guard
        let data = try? encoder.encode(value),
        let string = String(data: data, encoding: .utf8)
      else {
        preconditionFailure("Failed to encode operational record as UTF-8 JSON.")
      }

      return string
    }

    return lines.joined(separator: "\n") + "\n"
  }

  private static func decodeJSONLines<T: Decodable>(
    relativePath: String,
    projectRoot: URL,
    as type: T.Type
  ) throws -> [T] {
    let document = try readDocument(
      relativePath: relativePath,
      projectRoot: projectRoot
    )
    let decoder = JSONDecoder()
    var results: [T] = []

    for (index, line) in document.split(separator: "\n").enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        continue
      }

      guard let data = trimmed.data(using: .utf8) else {
        throw OperationalRecordError.invalidJSONL(
          "\(relativePath): line \(index + 1): failed to encode JSON line as UTF-8."
        )
      }

      do {
        results.append(try decoder.decode(T.self, from: data))
      } catch {
        throw OperationalRecordError.invalidJSONL(
          "\(relativePath): line \(index + 1): \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  private static func decodeOptionalJSONLines<T: Decodable>(
    relativePath: String,
    projectRoot: URL,
    as type: T.Type
  ) throws -> [T] {
    let url = projectRoot.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }
    return try decodeJSONLines(
      relativePath: relativePath,
      projectRoot: projectRoot,
      as: type
    )
  }

  private static func latestEventMap<T>(
    events: [T],
    keyPath: KeyPath<T, String>
  ) -> [String: T] where T: HasEntryID {
    var latestByKey: [String: T] = [:]

    for event in events {
      let key = event[keyPath: keyPath]
      if let existing = latestByKey[key] {
        if event.entryId > existing.entryId {
          latestByKey[key] = event
        }
      } else {
        latestByKey[key] = event
      }
    }

    return latestByKey
  }

  private static func formatIDList(_ values: [String]) -> String {
    guard !values.isEmpty else {
      return ""
    }

    return values.map { "`\($0)`" }.joined(separator: ", ")
  }

  private static func escapeTableCell(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "|", with: "\\|")
  }
}

private protocol HasEntryID {
  var entryId: String { get }
}

extension Sequence {
  fileprivate func sorted<Value: Comparable>(
    by keyPath: KeyPath<Element, Value>
  ) -> [Element] {
    sorted { lhs, rhs in
      lhs[keyPath: keyPath] < rhs[keyPath: keyPath]
    }
  }
}

public struct PartnerContextEvent: Codable, Equatable, Sendable, HasEntryID {
  public let entryId: String
  public let date: String
  public let sessionId: String
  public let summary: String
  public let implications: String
  public let affectedIds: [String]
  public let nextAction: String
  public let verification: String
  public let details: [String: String]?
}

public struct PartnerHandoffEvent: Codable, Equatable, Sendable, HasEntryID {
  public let entryId: String
  public let handoffId: String
  public let date: String
  public let sessionId: String
  public let title: String
  public let ownerRef: String
  public let writeScope: String
  public let acceptanceCriteria: String
  public let risks: String
  public let status: String
  public let eventType: String
  public let details: [String: String]?
}

public struct GitHistoryProposalEvent: Codable, Equatable, Sendable, HasEntryID {
  public let entryId: String
  public let proposalId: String
  public let date: String
  public let sessionId: String
  public let analysisPassId: String
  public let candidateCommit: String
  public let proposedAction: String
  public let rationale: String
  public let risk: String
  public let commandPlan: String
  public let approvalStatus: String
  public let eventType: String
  public let details: [String: String]?
}

private struct GardeningEventProjection: Codable, Sendable {
  let entryId: String
  let date: String
  let sessionId: String
  let phaseLabel: String
  let scope: String
  let category: String
  let subject: String
  let proposedAction: String
  let decision: String
  let rationale: String
  let affectedArtifacts: [String]
  let validationStatus: String
  let reviewer: String
}

private struct GitHistoryGardenerEntry: Codable, Sendable {
  let entryId: String
  let date: String
  let sessionId: String
  let phaseLabel: String
  let scope: String
  let category: String
  let subject: String
  let commitRange: String
  let candidateCommit: String
  let proposedAction: String
  let decision: String
  let rationale: String
  let affectedArtifacts: [String]
  let validationStatus: String
  let reviewer: String
}
