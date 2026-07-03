import Foundation
import Testing

@testable import ContextCore

struct ChecksManifestMarkdownRendererTests {
  /// A manifest exercising all three classes plus an unrepresented mandate: a read-only
  /// persona (two class-1 denials + a prose non-goal) and a directive with one command and
  /// one review gate. The golden fixtures never populate class-1, so this is where the
  /// capability-deny bullet rendering is covered.
  private func fullManifest() -> ChecksManifest {
    let persona = Persona(
      id: "read-only-auditor",
      version: "1.0",
      name: "Read-Only Auditor",
      summary: "Inspects without mutating.",
      responsibilities: [],
      values: [],
      nonGoals: ["ship product changes"],
      defaultKitIds: [],
      allowedSkillIds: [],
      forbiddenSkillIds: [],
      forbiddenCapabilities: ["edit-files", "run-commands"]
    )
    let directive = Directive(
      id: "apply-style",
      version: "1.0",
      title: "Apply style",
      goal: "Match the style guides.",
      steps: [Directive.Step(text: "Get sign-off", requiresReview: true)],
      acceptanceCriteria: [],
      verification: [
        Directive.VerificationItem(kind: "command", text: "swift test"),
        Directive.VerificationItem(kind: "manual", text: "Eyeball AA on device"),
      ],
      requiresSkillIds: []
    )
    return ChecksManifestDeriver.derive(sessionId: nil, persona: persona, directive: directive)
  }

  @Test
  func rendersEachClassProvenanceAndUnrepresented() {
    let lines = ChecksManifestMarkdownRenderer.boundariesLines(fullManifest())

    #expect(lines.first == "# Boundaries")
    // Class-1 capability-deny bullets (uncovered by the export goldens).
    #expect(lines.contains("Class 1 — hook (deterministic deny):"))
    #expect(
      lines.contains("- capability-deny.edit-files — deny file-mutation — persona:read-only-auditor [forbiddenCapabilities]")
    )
    #expect(
      lines.contains("- capability-deny.run-commands — deny command-execution — persona:read-only-auditor [forbiddenCapabilities]")
    )
    // Class-2 command is backticked and points at directive verification.
    #expect(
      lines.contains("- command.swift-test — `swift test` — directive:apply-style [verification]")
    )
    // Class-3 review gate from a requires-review step.
    #expect(
      lines.contains("- review.get-sign-off — Get sign-off — directive:apply-style [steps]")
    )
    // Manual verification is a review gate, not a command.
    #expect(
      lines.contains("- review.eyeball-aa-on-device — Eyeball AA on device — directive:apply-style [verification]")
    )
    // Prose non-goal surfaced honestly rather than dropped.
    #expect(
      lines.contains("Not yet checkable (represented, not enforced):")
    )
    #expect(lines.contains("- ship product changes — persona:read-only-auditor [nonGoals]"))
  }

  @Test
  func emptyClassesRenderInlineNoneAndOmitUnrepresented() {
    let manifest = ChecksManifest(
      sessionId: nil,
      personaId: "p",
      directiveId: nil,
      checks: [],
      unrepresentedMandates: [],
      summary: ChecksManifestSummary(
        hookCount: 0,
        commandCount: 0,
        reviewCount: 0,
        unrepresentedCount: 0
      )
    )

    let lines = ChecksManifestMarkdownRenderer.boundariesLines(manifest)

    #expect(lines.contains("Class 1 — hook (deterministic deny): none"))
    #expect(lines.contains("Class 2 — command (exit-code gate): none"))
    #expect(lines.contains("Class 3 — review (human or agent sign-off): none"))
    // No mandates to report, so the exception block is omitted entirely.
    #expect(!lines.contains("Not yet checkable (represented, not enforced):"))
  }

  @Test
  func renderIsDeterministic() {
    let manifest = fullManifest()
    #expect(
      ChecksManifestMarkdownRenderer.boundariesLines(manifest)
        == ChecksManifestMarkdownRenderer.boundariesLines(manifest)
    )
  }
}
