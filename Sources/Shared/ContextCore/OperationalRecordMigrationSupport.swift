import Foundation

enum OperationalRecordMigrationSupport {
  static func buildMigrationOutput(
    root: URL
  ) throws -> OperationalRecordMigrationOutput {
    let projectRoot = root.deletingLastPathComponent()
    let partnerContextDocument = try readDocument(
      relativePath: OperationalRecordBuilder.partnerContextProjectionRelativePath,
      projectRoot: projectRoot
    )
    let partnerHandoffDocument = try readDocument(
      relativePath: OperationalRecordBuilder.partnerHandoffsProjectionRelativePath,
      projectRoot: projectRoot
    )
    let gitHistoryProposalsDocument = try readDocument(
      relativePath: OperationalRecordBuilder.gitHistoryProposalsProjectionRelativePath,
      projectRoot: projectRoot
    )
    try assertLegacyImportDocument(
      partnerContextDocument,
      relativePath: OperationalRecordBuilder.partnerContextProjectionRelativePath
    )
    try assertLegacyImportDocument(
      partnerHandoffDocument,
      relativePath: OperationalRecordBuilder.partnerHandoffsProjectionRelativePath
    )
    try assertLegacyImportDocument(
      gitHistoryProposalsDocument,
      relativePath: OperationalRecordBuilder.gitHistoryProposalsProjectionRelativePath
    )
    let gitHistoryEntries = try OperationalRecordJSONLSupport.decodeOptionalJSONLines(
      relativePath: OperationalRecordBuilder.gitHistoryGardenerRelativePath,
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
        OperationalRecordBuilder.partnerContextEventsRelativePath:
          OperationalRecordJSONLSupport.encodeJSONLines(partnerContextEvents),
        OperationalRecordBuilder.partnerHandoffsRelativePath:
          OperationalRecordJSONLSupport.encodeJSONLines(partnerHandoffs),
        OperationalRecordBuilder.gitHistoryProposalsRelativePath:
          OperationalRecordJSONLSupport.encodeJSONLines(gitHistoryProposals),
      ]
    )
  }

  static func readDocument(
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
