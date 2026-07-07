import Foundation
import Testing

@testable import ContextCore

struct ChecksManifestTests {
  /// Builds a persona with explicit forbidden-capability and non-goal sets.
  private func persona(
    id: String = "read-only-auditor",
    nonGoals: [String] = [],
    forbiddenCapabilities: [String]?
  ) -> Persona {
    Persona(
      id: id,
      version: "1.0",
      name: "Read-Only Auditor",
      summary: "Inspects without mutating.",
      responsibilities: [],
      values: [],
      nonGoals: nonGoals,
      defaultKitIds: [],
      allowedSkillIds: [],
      forbiddenSkillIds: [],
      forbiddenCapabilities: forbiddenCapabilities
    )
  }

  /// Builds a directive with the given steps and verification items.
  private func directive(
    id: String = "apply-style",
    steps: [Directive.Step] = [],
    verification: [Directive.VerificationItem]
  ) -> Directive {
    Directive(
      id: id,
      version: "1.0",
      title: "Apply style",
      goal: "Match the style guides.",
      steps: steps,
      acceptanceCriteria: [],
      verification: verification,
      requiresSkillIds: []
    )
  }

  @Test
  func readOnlyStanceDeniesFileMutationAndCommandExecution() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: ["run-commands", "edit-files"]),
      directive: nil
    )

    // Vocabulary-ordered, one hook check per forbidden capability.
    #expect(manifest.checks.map(\.id) == ["capability-deny.edit-files", "capability-deny.run-commands"])
    #expect(manifest.checks.allSatisfy { $0.maxClass == "hook" })

    let editRule = manifest.checks[0].rule
    #expect(editRule.kind == .capabilityDeny)
    #expect(editRule.deniedActionClasses == ["file-mutation"])

    // The shell-bypass closure: forbidding run-commands independently denies
    // command-execution, so a read-only stance covers Bash by construction.
    let runRule = manifest.checks[1].rule
    #expect(runRule.deniedActionClasses == ["command-execution"])

    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 2, commandCount: 0, reviewCount: 0, unrepresentedCount: 0)
    )
  }

  @Test
  func verificationSplitsCommandFromReviewByKind() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: "senior-swiftui-engineer_apply-style",
      persona: persona(forbiddenCapabilities: nil),
      directive: directive(verification: [
        Directive.VerificationItem(kind: "command", text: "swift test"),
        Directive.VerificationItem(kind: "manual", text: "Review diff for scope creep"),
      ])
    )

    #expect(manifest.checks.map(\.id) == ["command.swift-test", "review.review-diff-for-scope-creep"])

    let command = manifest.checks[0]
    #expect(command.maxClass == "command")
    #expect(command.rule.command == "swift test")
    #expect(command.source == CheckSource(sourceType: "directive", sourceId: "apply-style", field: "verification"))

    let review = manifest.checks[1]
    #expect(review.maxClass == "review")
    #expect(review.rule.kind == .review)
    #expect(review.rule.criterion == "Review diff for scope creep")

    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 0, commandCount: 1, reviewCount: 1, unrepresentedCount: 0)
    )
  }

  @Test
  func requiresReviewStepsBecomeReviewChecksBeforeVerificationItems() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: nil),
      directive: directive(
        steps: [
          Directive.Step(text: "Identify the target files.", requiresReview: nil),
          Directive.Step(text: "Avoid unrelated refactors.", requiresReview: true),
        ],
        verification: [
          Directive.VerificationItem(kind: "command", text: "swift test"),
          Directive.VerificationItem(kind: "manual", text: "Review diff for scope creep"),
        ]
      )
    )

    // The requiresReview step is the plan's emblematic class-3 mandate; it now surfaces.
    #expect(
      manifest.checks.map(\.id) == [
        "command.swift-test",
        "review.avoid-unrelated-refactors",
        "review.review-diff-for-scope-creep",
      ]
    )
    let stepReview = manifest.checks[1]
    #expect(stepReview.source == CheckSource(sourceType: "directive", sourceId: "apply-style", field: "steps"))
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 0, commandCount: 1, reviewCount: 2, unrepresentedCount: 0)
    )
  }

  @Test
  func hookThenCommandThenReviewOrderingIsStable() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: ["edit-files"]),
      directive: directive(verification: [
        Directive.VerificationItem(kind: "manual", text: "Eyeball AA on device"),
        Directive.VerificationItem(kind: "command", text: "swift test"),
      ])
    )

    #expect(manifest.checks.map(\.maxClass) == ["hook", "command", "review"])
    #expect(manifest.checks.map(\.id) == ["capability-deny.edit-files", "command.swift-test", "review.eyeball-aa-on-device"])
  }

  @Test
  func checkIdsAreStableWhenVerificationItemsAreReordered() {
    let forward = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: nil),
      directive: directive(verification: [
        Directive.VerificationItem(kind: "command", text: "swift test"),
        Directive.VerificationItem(kind: "command", text: "swift run personakit validate"),
      ])
    )
    let reversed = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: nil),
      directive: directive(verification: [
        Directive.VerificationItem(kind: "command", text: "swift run personakit validate"),
        Directive.VerificationItem(kind: "command", text: "swift test"),
      ])
    )

    // Content-derived ids: reordering changes order, never the id a mandate carries.
    #expect(Set(forward.checks.map(\.id)) == Set(reversed.checks.map(\.id)))
    #expect(forward.checks.map(\.id) == ["command.swift-test", "command.swift-run-personakit-validate"])
  }

  @Test
  func duplicateReviewTextsGetUniqueSuffixedIds() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: nil),
      directive: directive(verification: [
        Directive.VerificationItem(kind: "manual", text: "Confirm behavior"),
        Directive.VerificationItem(kind: "manual", text: "Confirm behavior"),
      ])
    )

    #expect(manifest.checks.map(\.id) == ["review.confirm-behavior", "review.confirm-behavior-2"])
  }

  @Test
  func unknownForbiddenCapabilityIsSurfacedNotDropped() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: ["edit-files", "delete-production-database"]),
      directive: nil
    )

    // Only the known capability becomes a hook check.
    #expect(manifest.checks.map(\.id) == ["capability-deny.edit-files"])

    // The unknown capability is reported, not silently lost.
    #expect(manifest.unrepresentedMandates.count == 1)
    let unrepresented = manifest.unrepresentedMandates[0]
    #expect(unrepresented.mandate == "Forbidden capability 'delete-production-database'.")
    #expect(unrepresented.source == CheckSource(sourceType: "persona", sourceId: "read-only-auditor", field: "forbiddenCapabilities"))
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 1, commandCount: 0, reviewCount: 0, unrepresentedCount: 1)
    )
  }

  @Test
  func proseNonGoalsAreSurfacedAsUnrepresented() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(
        nonGoals: ["architecture rewrites", "introducing new frameworks"],
        forbiddenCapabilities: nil
      ),
      directive: nil
    )

    #expect(manifest.checks.isEmpty)
    #expect(manifest.unrepresentedMandates.map(\.mandate) == ["architecture rewrites", "introducing new frameworks"])
    #expect(manifest.unrepresentedMandates.allSatisfy { $0.source.field == "nonGoals" })
  }

  @Test
  func hookCheckLooksUpDenyingCheckByActionClassHostNeutrally() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: ["edit-files", "run-commands"]),
      directive: nil
    )

    #expect(manifest.hookCheck(denying: "file-mutation")?.id == "capability-deny.edit-files")
    #expect(manifest.hookCheck(denying: "command-execution")?.id == "capability-deny.run-commands")
    #expect(manifest.hookCheck(denying: "network-egress") == nil)
    #expect(manifest.hookCheck(denying: "inspection") == nil)
  }

  @Test
  func emptyContractYieldsEmptyManifest() {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(forbiddenCapabilities: nil),
      directive: nil
    )

    #expect(manifest.checks.isEmpty)
    #expect(manifest.unrepresentedMandates.isEmpty)
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 0, commandCount: 0, reviewCount: 0, unrepresentedCount: 0)
    )
  }

  @Test
  func encodingIsDeterministicAcrossRuns() throws {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: nil,
      persona: persona(
        nonGoals: ["architecture rewrites"],
        forbiddenCapabilities: ["edit-files", "run-commands", "network-access"]
      ),
      directive: directive(
        steps: [Directive.Step(text: "Avoid unrelated refactors.", requiresReview: true)],
        verification: [
          Directive.VerificationItem(kind: "command", text: "swift test"),
          Directive.VerificationItem(kind: "manual", text: "Review diff for scope creep"),
        ]
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let first = try encoder.encode(manifest)
    let second = try encoder.encode(manifest)

    #expect(first == second)
  }

  @Test
  func encodedManifestValidatesAgainstBundledSchema() throws {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: "senior-swiftui-engineer_apply-style",
      persona: persona(
        nonGoals: ["architecture rewrites"],
        forbiddenCapabilities: ["edit-files", "run-commands", "not-a-real-capability"]
      ),
      directive: directive(
        steps: [Directive.Step(text: "Avoid unrelated refactors.", requiresReview: true)],
        verification: [
          Directive.VerificationItem(kind: "command", text: "swift test"),
          Directive.VerificationItem(kind: "manual", text: "Review diff for scope creep"),
        ]
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)

    let errors = SchemaValidator.validate(
      jsonData: data,
      schemaName: "checks.schema.json",
      relativePath: "checks-manifest.json"
    )

    #expect(errors.isEmpty)
  }

  @Test
  func readOnlySessionFixtureDerivesHookChecksIncludingShellBypassClosure() throws {
    let scopes = ScopeSet(projectScopeURL: readOnlyFixtureRootURL(), globalScopeURL: nil)
    let session = try SessionFileLoader.load(scopes: scopes, sessionId: "read-only-auditor_audit-pass")
    let result = try SessionContractResolver.resolve(scopes: scopes, session: session)

    let manifest = ChecksManifestDeriver.derive(from: result)

    #expect(manifest.sessionId == "read-only-auditor_audit-pass")
    #expect(
      manifest.checks.map(\.id) == [
        "capability-deny.edit-files",
        "capability-deny.network-access",
        "capability-deny.run-commands",
        "command.swift-test",
        "review.report-confirmed-issues-before-suggestions",
        "review.no-unrelated-refactors-introduced",
      ]
    )
    // Read-only stance closes the shell-bypass path: run-commands denies
    // command-execution, so Bash is covered without special-casing.
    let deniedActionClasses = Set(manifest.checks.compactMap { $0.rule.deniedActionClasses }.flatMap { $0 })
    #expect(deniedActionClasses.isSuperset(of: ["file-mutation", "command-execution"]))
    // The persona's prose non-goals are surfaced honestly rather than dropped.
    #expect(manifest.unrepresentedMandates.map(\.mandate) == ["code editing", "running build or test commands"])
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 3, commandCount: 1, reviewCount: 2, unrepresentedCount: 2)
    )
  }

  @Test
  func derivesFromResolvedContractResult() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let result = try SessionContractResolver.resolve(
      scopes: scopes,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    let manifest = ChecksManifestDeriver.derive(from: result)

    // The fixture persona forbids no capabilities, so class-2/3 come from the real
    // directive: one command gate, one requiresReview step, one manual review gate.
    #expect(manifest.personaId == "senior-swiftui-engineer")
    #expect(manifest.directiveId == "apply-style")
    #expect(
      manifest.checks.map(\.id) == [
        "command.swift-test",
        "review.avoid-unrelated-refactors",
        "review.review-diff-for-scope-creep",
      ]
    )
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 0, commandCount: 1, reviewCount: 2, unrepresentedCount: 3)
    )
  }
}
