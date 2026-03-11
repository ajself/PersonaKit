import Foundation
import Testing

@testable import ContextCore

struct OperationalRecordsTests {
  @Test
  func migrationImportsLegacyMarkdownIntoCanonicalJSONL() throws {
    let fixture = try makeOperationalRecordsProjectFixture(
      seedCanonicalRecords: false
    )

    let output = try OperationalRecordBuilder.buildMigrationOutput(
      root: fixture.personaKitRoot
    )

    let partnerContextURL = fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.partnerContextEventsRelativePath
    )
    let partnerHandoffsURL = fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.partnerHandoffsRelativePath
    )
    let gitHistoryProposalsURL = fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.gitHistoryProposalsRelativePath
    )

    try output.files[OperationalRecordBuilder.partnerContextEventsRelativePath]?
      .write(
        to: partnerContextURL,
        atomically: true,
        encoding: .utf8
      )
    try output.files[OperationalRecordBuilder.partnerHandoffsRelativePath]?
      .write(
        to: partnerHandoffsURL,
        atomically: true,
        encoding: .utf8
      )
    try output.files[OperationalRecordBuilder.gitHistoryProposalsRelativePath]?
      .write(
        to: gitHistoryProposalsURL,
        atomically: true,
        encoding: .utf8
      )

    let partnerContextEvents = try decodeJSONLines(
      at: partnerContextURL,
      as: PartnerContextEvent.self
    )
    let partnerHandoffs = try decodeJSONLines(
      at: partnerHandoffsURL,
      as: PartnerHandoffEvent.self
    )
    let gitHistoryProposals = try decodeJSONLines(
      at: gitHistoryProposalsURL,
      as: GitHistoryProposalEvent.self
    )

    #expect(partnerContextEvents.count == 2)
    #expect(partnerContextEvents.last?.entryId == "PCL-0002")
    #expect(
      partnerContextEvents.last?.affectedIds == [
        "samwise",
        "partner-context-log",
        "partner-handoff-register",
      ]
    )

    #expect(partnerHandoffs.count == 2)
    #expect(partnerHandoffs.last?.handoffId == "HOF-002")
    #expect(partnerHandoffs.last?.status == "In Progress")

    #expect(gitHistoryProposals.count == 2)
    #expect(gitHistoryProposals.first?.proposalId == "GHP-001")
    #expect(gitHistoryProposals.first?.analysisPassId == "analysis-pass-1")
    #expect(gitHistoryProposals.last?.approvalStatus == "approved")
  }

  @Test
  func generatedDocsMaterializeLatestStateAndPreserveEventHistory() throws {
    let fixture = try makeOperationalRecordsProjectFixture()
    let partnerContextEvents = [
      PartnerContextEvent(
        entryId: "PCL-0001",
        date: "2026-03-10",
        sessionId: "samwise-partner-sync",
        summary: "Stabilize continuity",
        implications: "Canonical logs are preferred",
        affectedIds: [
          "samwise"
        ],
        nextAction: "Define canonical partner resource",
        verification: "pass",
        details: nil
      )
    ]
    let partnerHandoffs = [
      PartnerHandoffEvent(
        entryId: "PHF-0001",
        handoffId: "HOF-001",
        date: "2026-03-10",
        sessionId: "samwise-partner-sync",
        title: "Prepare migration",
        ownerRef: "`samwise` / `samwise-partner-sync`",
        writeScope: "Docs only",
        acceptanceCriteria: "Importer drafted",
        risks: "Drift",
        status: "In Progress",
        eventType: "recorded",
        details: nil
      ),
      PartnerHandoffEvent(
        entryId: "PHF-0002",
        handoffId: "HOF-001",
        date: "2026-03-11",
        sessionId: "samwise-partner-sync",
        title: "Prepare migration",
        ownerRef: "`samwise` / `samwise-partner-sync`",
        writeScope: "Docs and CLI",
        acceptanceCriteria: "Importer and projections land",
        risks: "Residual drift if checks are skipped",
        status: "Complete",
        eventType: "completed",
        details: nil
      ),
    ]
    let gitHistoryProposals = [
      GitHistoryProposalEvent(
        entryId: "GHL-0001",
        proposalId: "GHP-001",
        date: "2026-03-10",
        sessionId: "git-history-gardener",
        analysisPassId: "analysis-pass-3",
        candidateCommit: "abc1234",
        proposedAction: "fixup-followup",
        rationale: "Reads as one unit.",
        risk: "Low",
        commandPlan: "git rebase -i HEAD~4",
        approvalStatus: "pending",
        eventType: "proposed",
        details: nil
      ),
      GitHistoryProposalEvent(
        entryId: "GHL-0002",
        proposalId: "GHP-001",
        date: "2026-03-11",
        sessionId: "git-history-gardener",
        analysisPassId: "analysis-pass-4",
        candidateCommit: "abc1234",
        proposedAction: "fixup-followup",
        rationale: "Reads as one unit.",
        risk: "Low",
        commandPlan: "git rebase -i HEAD~4",
        approvalStatus: "approved",
        eventType: "approved",
        details: nil
      ),
    ]

    try writeCanonicalOperationalRecords(
      fixture: fixture,
      partnerContextEvents: partnerContextEvents,
      partnerHandoffs: partnerHandoffs,
      gitHistoryProposals: gitHistoryProposals
    )

    let docsOutput = try OperationalRecordBuilder.buildDocsOutput(
      root: fixture.personaKitRoot
    )
    let partnerHandoffDoc = try #require(
      docsOutput.files[OperationalRecordBuilder.partnerHandoffsProjectionRelativePath]
    )
    let proposalDoc = try #require(
      docsOutput.files[OperationalRecordBuilder.gitHistoryProposalsProjectionRelativePath]
    )

    #expect(partnerHandoffDoc.contains("## Current Handoff State"))
    #expect(partnerHandoffDoc.contains("## Event History"))
    #expect(partnerHandoffDoc.contains("| 2026-03-11 | `HOF-001` | Prepare migration"))
    #expect(partnerHandoffDoc.contains("`PHF-0001`"))
    #expect(partnerHandoffDoc.contains("`PHF-0002`"))

    #expect(proposalDoc.contains("## Current Analysis Pass"))
    #expect(proposalDoc.contains("## Proposed Changes (Pending Approval)"))
    #expect(proposalDoc.contains("## Event History"))
    #expect(proposalDoc.contains("- None in current analysis pass (`analysis-pass-4`)."))
    #expect(proposalDoc.contains("`GHL-0001`"))
    #expect(proposalDoc.contains("`GHL-0002`"))
  }

  @Test
  func migrationRejectsGeneratedProjectionDocs() throws {
    let fixture = try makeOperationalRecordsProjectFixture()
    let docsOutput = try OperationalRecordBuilder.buildDocsOutput(
      root: fixture.personaKitRoot
    )
    for (relativePath, contents) in docsOutput.files {
      try contents.write(
        to: fixture.projectRoot.appendingPathComponent(relativePath),
        atomically: true,
        encoding: .utf8
      )
    }

    do {
      _ = try OperationalRecordBuilder.buildMigrationOutput(
        root: fixture.personaKitRoot
      )
      Issue.record("Expected generated projection import failure.")
    } catch let error as OperationalRecordError {
      switch error {
      case .bootstrapOnlyImport(let message):
        #expect(message.contains("generated projection"))
      default:
        Issue.record("Unexpected error: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
