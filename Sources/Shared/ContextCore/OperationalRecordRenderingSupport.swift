import Foundation

enum OperationalRecordRenderingSupport {
  static func buildDocsOutput(
    root: URL
  ) throws -> OperationalRecordDocsOutput {
    let projectRoot = root.deletingLastPathComponent()
    let partnerContextEvents = try OperationalRecordJSONLSupport.decodeJSONLines(
      relativePath: OperationalRecordBuilder.partnerContextEventsRelativePath,
      projectRoot: projectRoot,
      as: PartnerContextEvent.self
    )
    let partnerHandoffs = try OperationalRecordJSONLSupport.decodeJSONLines(
      relativePath: OperationalRecordBuilder.partnerHandoffsRelativePath,
      projectRoot: projectRoot,
      as: PartnerHandoffEvent.self
    )
    let gardeningEvents = try OperationalRecordJSONLSupport.decodeJSONLines(
      relativePath: OperationalRecordBuilder.gardeningEventsRelativePath,
      projectRoot: projectRoot,
      as: GardeningEventProjection.self
    )
    let gitHistoryEntries = try OperationalRecordJSONLSupport.decodeJSONLines(
      relativePath: OperationalRecordBuilder.gitHistoryGardenerRelativePath,
      projectRoot: projectRoot,
      as: GitHistoryGardenerEntry.self
    )
    let gitHistoryProposals = try OperationalRecordJSONLSupport.decodeJSONLines(
      relativePath: OperationalRecordBuilder.gitHistoryProposalsRelativePath,
      projectRoot: projectRoot,
      as: GitHistoryProposalEvent.self
    )

    return OperationalRecordDocsOutput(
      files: [
        OperationalRecordBuilder.partnerContextProjectionRelativePath: renderPartnerContextLog(
          events: partnerContextEvents
        ),
        OperationalRecordBuilder.partnerHandoffsProjectionRelativePath: renderPartnerHandoffRegister(
          events: partnerHandoffs
        ),
        OperationalRecordBuilder.packGardenerProjectionRelativePath: renderPackGardenerLog(
          events: gardeningEvents
        ),
        OperationalRecordBuilder.gitHistoryGardenerProjectionRelativePath: renderGitHistoryGardenerLog(
          entries: gitHistoryEntries
        ),
        OperationalRecordBuilder.gitHistoryProposalsProjectionRelativePath: renderGitHistoryProposalLog(
          entries: gitHistoryEntries,
          events: gitHistoryProposals
        ),
      ]
    )
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
        "| \(event.date) | \(OperationalRecordJSONLSupport.escapeTableCell(event.summary)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.implications)) | "
          + "\(OperationalRecordJSONLSupport.formatIDList(event.affectedIds)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.nextAction)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.verification)) |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderPartnerHandoffRegister(
    events: [PartnerHandoffEvent]
  ) -> String {
    let latestByHandoff = OperationalRecordJSONLSupport.latestEventMap(
      events: events,
      keyPath: \.handoffId,
      entryIDKeyPath: \.entryId
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
        "| \(event.date) | `\(event.handoffId)` | \(OperationalRecordJSONLSupport.escapeTableCell(event.title)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.ownerRef)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.writeScope)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.acceptanceCriteria)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.risks)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.status)) |"
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

    for event in events.sorted(by: { $0.entryId < $1.entryId }) {
      lines.append(
        "| `\(event.entryId)` | `\(event.handoffId)` | \(event.date) | `\(event.sessionId)` | "
          + "`\(event.eventType)` | \(OperationalRecordJSONLSupport.escapeTableCell(event.title)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.ownerRef)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.writeScope)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.acceptanceCriteria)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.risks)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.status)) |"
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
        "| \(event.date) | \(OperationalRecordJSONLSupport.escapeTableCell(event.phaseLabel)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.subject)) | "
          + "\(decision) | \(OperationalRecordJSONLSupport.formatIDList(event.affectedArtifacts)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.validationStatus)) |"
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
        "| \(entry.date) | \(OperationalRecordJSONLSupport.escapeTableCell(entry.phaseLabel)) | "
          + "`\(entry.commitRange)` | `\(entry.candidateCommit)` | `\(entry.proposedAction)` | "
          + "`\(entry.decision)` | `\(entry.validationStatus)` |"
      )
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  private static func renderGitHistoryProposalLog(
    entries: [GitHistoryGardenerEntry],
    events: [GitHistoryProposalEvent]
  ) -> String {
    let latestByProposal = OperationalRecordJSONLSupport.latestEventMap(
      events: events,
      keyPath: \.proposalId,
      entryIDKeyPath: \.entryId
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
            + "\(OperationalRecordJSONLSupport.escapeTableCell(event.rationale)) | "
            + "\(OperationalRecordJSONLSupport.escapeTableCell(event.risk)) | "
            + "\(OperationalRecordJSONLSupport.escapeTableCell(event.commandPlan)) | "
            + "\(OperationalRecordJSONLSupport.escapeTableCell(event.approvalStatus)) |"
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

    for event in events.sorted(by: { $0.entryId < $1.entryId }) {
      lines.append(
        "| `\(event.entryId)` | `\(event.proposalId)` | \(event.date) | `\(event.analysisPassId)` | "
          + "`\(event.candidateCommit)` | `\(event.proposedAction)` | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.rationale)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.risk)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.commandPlan)) | "
          + "\(OperationalRecordJSONLSupport.escapeTableCell(event.approvalStatus)) | "
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
