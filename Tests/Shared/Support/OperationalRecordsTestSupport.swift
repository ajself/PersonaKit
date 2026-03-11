import ContextCore
import Foundation

struct OperationalRecordsProjectFixture {
  let projectRoot: URL
  let personaKitRoot: URL
  let developmentRoot: URL
  let logsRoot: URL

  let partnerContextLogURL: URL
  let partnerHandoffRegisterURL: URL
  let packGardenerLogURL: URL
  let gitHistoryGardenerLogURL: URL
  let gitHistoryProposalsURL: URL
}

func makeOperationalRecordsProjectFixture(
  seedCanonicalRecords: Bool = true
) throws -> OperationalRecordsProjectFixture {
  let projectRoot = try makeTempDirectory().appendingPathComponent(
    "OperationalRecordsProject"
  )
  try FileManager.default.createDirectory(
    at: projectRoot,
    withIntermediateDirectories: true
  )

  let personaKitRoot = projectRoot.appendingPathComponent(".personakit")
  try copyFixtureKit(to: personaKitRoot)

  let developmentRoot = projectRoot.appendingPathComponent(
    "Docs/PersonaKit/Development"
  )
  let logsRoot = developmentRoot.appendingPathComponent("logs")
  try FileManager.default.createDirectory(
    at: logsRoot,
    withIntermediateDirectories: true
  )

  let fixture = OperationalRecordsProjectFixture(
    projectRoot: projectRoot,
    personaKitRoot: personaKitRoot,
    developmentRoot: developmentRoot,
    logsRoot: logsRoot,
    partnerContextLogURL: developmentRoot.appendingPathComponent(
      "partner-context-log.md"
    ),
    partnerHandoffRegisterURL: developmentRoot.appendingPathComponent(
      "partner-handoff-register.md"
    ),
    packGardenerLogURL: developmentRoot.appendingPathComponent(
      "pack-gardener-log.md"
    ),
    gitHistoryGardenerLogURL: developmentRoot.appendingPathComponent(
      "git-history-gardener-log.md"
    ),
    gitHistoryProposalsURL: developmentRoot.appendingPathComponent(
      "git-history-gardener-proposals.md"
    )
  )

  try writeFixtureOperationalMarkdown(to: fixture)
  try writeFixtureOperationalSupportingJSONL(to: fixture)

  if seedCanonicalRecords {
    let migration = try OperationalRecordBuilder.buildMigrationOutput(
      root: fixture.personaKitRoot
    )
    try writeFiles(
      migration.files,
      projectRoot: fixture.projectRoot
    )
  }

  return fixture
}

func writeCanonicalOperationalRecords(
  fixture: OperationalRecordsProjectFixture,
  partnerContextEvents: [PartnerContextEvent],
  partnerHandoffs: [PartnerHandoffEvent],
  gitHistoryProposals: [GitHistoryProposalEvent]
) throws {
  try writeJSONLines(
    partnerContextEvents,
    to: fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.partnerContextEventsRelativePath
    )
  )
  try writeJSONLines(
    partnerHandoffs,
    to: fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.partnerHandoffsRelativePath
    )
  )
  try writeJSONLines(
    gitHistoryProposals,
    to: fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.gitHistoryProposalsRelativePath
    )
  )
}

func decodeJSONLines<T: Decodable>(
  at url: URL,
  as type: T.Type
) throws -> [T] {
  let decoder = JSONDecoder()
  return try String(contentsOf: url, encoding: .utf8)
    .split(separator: "\n")
    .map { line in
      try decoder.decode(T.self, from: Data(line.utf8))
    }
}

private func writeFixtureOperationalMarkdown(
  to fixture: OperationalRecordsProjectFixture
) throws {
  let partnerContext = """
    # Partner Context Log

    Status: Active  
    Owner: AJ  
    Last Reviewed: 2026-03-11

    ## Entries

    | Date | Update Summary | Implications | Affected IDs | Next Action | Verification |
    | --- | --- | --- | --- | --- | --- |
    | 2026-03-10 | Stabilize partner continuity | Partner updates need a durable canonical store | `samwise`, `trusted-partner-core` | Define canonical continuity resource | `personakit validate` passed |
    | 2026-03-11 | Adopt JSONL-first operational records | Markdown continuity notes should become generated projections | `samwise`, `partner-context-log`, `partner-handoff-register` | Build importer and projection tools | `personakit validate` passed |
    """
  let partnerHandoffs = """
    # Partner Handoff Register

    Status: Active  
    Owner: AJ  
    Last Reviewed: 2026-03-11

    ## Entries

    | Date | Handoff | Owner Persona/Session | Write Scope | Acceptance Criteria | Risks | Status |
    | --- | --- | --- | --- | --- | --- | --- |
    | 2026-03-10 | Prepare canonical partner continuity migration | `samwise` / `samwise-partner-sync` | `Docs/PersonaKit/Development/partner-context-log.md`, `Docs/PersonaKit/Development/partner-handoff-register.md` | Canonical importer exists and validation passes | Operators may still edit markdown until guidance is updated | Complete |
    | 2026-03-11 | Refresh operational record projections | `samwise` / `samwise-partner-sync` | `Docs/PersonaKit/Development/logs/partner-context-events.jsonl`, `Docs/PersonaKit/Development/logs/partner-handoffs.jsonl` | Generated docs stay aligned with canonical JSONL | Drift between markdown and JSONL if checks are skipped | In Progress |
    """
  let gitHistoryProposals = """
    # Git History Gardener Proposals

    Status: Active  
    Owner: AJ  
    Last Reviewed: 2026-03-11

    ## Current Analysis Pass

    - Session: `git-history-gardener`
    - Commit range: `HEAD~6..HEAD` (`abc1234..def5678`)
    - Mode: analysis only
    - Current analysis pass: `analysis-pass-4`

    ## Proposal History

    | Proposal ID | Candidate Commit | Proposed Action | Rationale | Risk | Exact Command Plan (Not Executed) | Approval Status |
    | --- | --- | --- | --- | --- | --- | --- |
    | GHP-001 | `abc1234` | `fixup-followup` | Narrow corrective follow-up that reads better as one history unit. | Low | `git rebase -i HEAD~4` | `pending` |
    | GHP-002 | `def5678` | `keep` | Commit marks a useful milestone boundary and should remain separate. | Low | `none` | `approved (executed)` |

    ## Execution Result (2026-03-11)

    - `GHP-002` was approved and already executed in a prior pass.
    """

  try partnerContext.write(
    to: fixture.partnerContextLogURL,
    atomically: true,
    encoding: .utf8
  )
  try partnerHandoffs.write(
    to: fixture.partnerHandoffRegisterURL,
    atomically: true,
    encoding: .utf8
  )
  try gitHistoryProposals.write(
    to: fixture.gitHistoryProposalsURL,
    atomically: true,
    encoding: .utf8
  )
}

private func writeFixtureOperationalSupportingJSONL(
  to fixture: OperationalRecordsProjectFixture
) throws {
  let gardeningEvents = [
    GardeningEventFixture(
      entryId: "GL-0001",
      date: "2026-03-10",
      sessionId: "pack-gardener-maintenance",
      phaseLabel: "migration-prep",
      scope: "repository-root",
      category: "pack-session",
      subject: "Prepare JSONL-first operational records migration",
      proposedAction: "plan",
      decision: "approved",
      rationale: "The canonical store should move away from hand-edited markdown tables.",
      affectedArtifacts: [
        "partner-context-log",
        "partner-handoff-register",
      ],
      validationStatus: "pass",
      reviewer: "AJ"
    ),
    GardeningEventFixture(
      entryId: "GL-0002",
      date: "2026-03-11",
      sessionId: "pack-gardener-maintenance",
      phaseLabel: "migration-implementation",
      scope: "repository-root",
      category: "pack-session",
      subject: "Implement importer and generated log projections",
      proposedAction: "update",
      decision: "approved",
      rationale: "Generated markdown should become a projection over canonical JSONL resources.",
      affectedArtifacts: [
        "OperationalRecords",
        "check-operational-records",
      ],
      validationStatus: "pass",
      reviewer: "AJ"
    ),
  ]
  let gitHistoryEntries = [
    GitHistoryGardenerFixtureEntry(
      entryId: "GHG-0001",
      date: "2026-03-10",
      sessionId: "git-history-gardener",
      phaseLabel: "analysis-pass-1",
      scope: "repository-root",
      category: "git-history",
      subject: "Review abc1234 for history cleanup",
      commitRange: "HEAD~6..HEAD",
      candidateCommit: "abc1234",
      proposedAction: "fixup-followup",
      decision: "deferred",
      rationale: "Approval has not been granted yet.",
      affectedArtifacts: [
        "git-history-gardener-proposals"
      ],
      validationStatus: "pass",
      reviewer: "AJ"
    ),
    GitHistoryGardenerFixtureEntry(
      entryId: "GHG-0002",
      date: "2026-03-10",
      sessionId: "git-history-gardener",
      phaseLabel: "analysis-pass-1",
      scope: "repository-root",
      category: "git-history",
      subject: "Review def5678 for history cleanup",
      commitRange: "HEAD~6..HEAD",
      candidateCommit: "def5678",
      proposedAction: "keep",
      decision: "deferred",
      rationale: "Milestone boundary should stay separate.",
      affectedArtifacts: [
        "git-history-gardener-proposals"
      ],
      validationStatus: "pass",
      reviewer: "AJ"
    ),
    GitHistoryGardenerFixtureEntry(
      entryId: "GHG-0003",
      date: "2026-03-11",
      sessionId: "git-history-gardener",
      phaseLabel: "analysis-pass-4",
      scope: "repository-root",
      category: "git-history",
      subject: "No current pending proposals in latest pass",
      commitRange: "HEAD~6..HEAD",
      candidateCommit: "none",
      proposedAction: "keep",
      decision: "deferred",
      rationale: "Current window is coherent.",
      affectedArtifacts: [
        "git-history-gardener-proposals"
      ],
      validationStatus: "pass",
      reviewer: "AJ"
    ),
  ]

  try writeJSONLines(
    gardeningEvents,
    to: fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.gardeningEventsRelativePath
    )
  )
  try writeJSONLines(
    gitHistoryEntries,
    to: fixture.projectRoot.appendingPathComponent(
      OperationalRecordBuilder.gitHistoryGardenerRelativePath
    )
  )
}

private func writeFiles(
  _ files: [String: String],
  projectRoot: URL
) throws {
  for (relativePath, contents) in files {
    let url = projectRoot.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}

private func writeJSONLines<T: Encodable>(
  _ values: [T],
  to url: URL
) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let lines = try values.map { value in
    let data = try encoder.encode(value)
    guard let line = String(data: data, encoding: .utf8) else {
      throw CocoaError(.fileWriteInapplicableStringEncoding)
    }
    return line
  }
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try (lines.joined(separator: "\n") + "\n").write(
    to: url,
    atomically: true,
    encoding: .utf8
  )
}

private struct GardeningEventFixture: Encodable {
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

private struct GitHistoryGardenerFixtureEntry: Encodable {
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
