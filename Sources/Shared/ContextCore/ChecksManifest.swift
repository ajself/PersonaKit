import Foundation

/// Host-relative enforcement ceiling for a derived check.
///
/// The class a mandate can actually reach is `mandate × host` (see the taxonomy in
/// the checkable-contracts plan). PK's core is host-neutral, so the manifest records
/// each mandate's intrinsic ceiling and reports host degradation in `hostNotes`; the
/// concrete per-host class is decided later by a host-specific renderer (Phase 1b).
public enum CheckClass: String, Codable, Sendable, CaseIterable {
  /// Class-1: deterministic pre-action deny (requires host deny-hooks).
  case hook

  /// Class-2: command verification — the exit code is the check.
  case command

  /// Class-3: review gate — a human or review-agent signs off. Not machine-enforceable.
  case review
}

/// Host-neutral, machine-readable rule backing a derived check.
///
/// The shape is a small discriminated union keyed by ``kind`` so it stays expressible
/// by the bundled JSON Schema validator (which has no conditional-required support).
/// Only the fields relevant to a rule's `kind` are populated; the rest encode as absent.
public struct CheckRule: Codable, Equatable, Sendable {
  /// The closed set of rule discriminators. `RawRepresentable` over `String` so the
  /// wire format stays the plain string the JSON Schema constrains, while callers get
  /// compile-time exhaustiveness instead of matching string literals.
  public enum Kind: String, Codable, Equatable, Sendable {
    case capabilityDeny = "capability-deny"
    case command
    case review
  }

  /// Rule discriminator selecting which of the fields below is populated.
  public let kind: Kind

  /// `capabilityDeny`: the forbidden host-neutral capability from the vocabulary.
  public let deniedCapability: String?

  /// `capabilityDeny`: host-neutral action classes a host must block for this mandate.
  public let deniedActionClasses: [String]?

  /// `command`: the exact command whose exit code is the check.
  public let command: String?

  /// `review`: the human-readable criterion a reviewer signs off.
  public let criterion: String?

  public init(
    kind: Kind,
    deniedCapability: String? = nil,
    deniedActionClasses: [String]? = nil,
    command: String? = nil,
    criterion: String? = nil
  ) {
    self.kind = kind
    self.deniedCapability = deniedCapability
    self.deniedActionClasses = deniedActionClasses
    self.command = command
    self.criterion = criterion
  }
}

/// Provenance for a derived check: which resolved entity and field produced it.
public struct CheckSource: Codable, Equatable, Sendable {
  /// Resolved entity type: `persona` or `directive`.
  public let sourceType: String

  /// Identifier of the source entity.
  public let sourceId: String

  /// Field on the source entity the mandate was read from.
  public let field: String

  public init(
    sourceType: String,
    sourceId: String,
    field: String
  ) {
    self.sourceType = sourceType
    self.sourceId = sourceId
    self.field = field
  }
}

/// A single classified check derived from a resolved contract.
public struct DerivedCheck: Codable, Equatable, Sendable {
  /// Stable, deterministic identifier for the check.
  public let id: String

  /// Human-readable statement of what must hold.
  public let mandate: String

  /// The intrinsic enforcement ceiling for this mandate (host-neutral).
  public let maxClass: String

  /// Host-neutral machine rule backing the check.
  public let rule: CheckRule

  /// Where the mandate came from in the resolved contract.
  public let source: CheckSource

  /// Host-relative degradation notes — how the reachable class changes by host.
  public let hostNotes: [String]

  public init(
    id: String,
    mandate: String,
    maxClass: String,
    rule: CheckRule,
    source: CheckSource,
    hostNotes: [String]
  ) {
    self.id = id
    self.mandate = mandate
    self.maxClass = maxClass
    self.rule = rule
    self.source = source
    self.hostNotes = hostNotes
  }
}

/// A mandate PK found in the contract but could *not* turn into a check.
///
/// Surfacing these is the honest posture: a guardrail that cannot be enforced yet is
/// reported out loud rather than silently dropped. Two sources today — a forbidden
/// capability outside the known vocabulary (no machine rule derivable) and prose
/// persona non-goals (the class-3 readiness gap).
public struct UnrepresentedMandate: Codable, Equatable, Sendable {
  /// Human-readable statement of the mandate as authored.
  public let mandate: String

  /// Where the mandate came from in the resolved contract.
  public let source: CheckSource

  /// Why PK could not derive a check for it.
  public let reason: String

  public init(
    mandate: String,
    source: CheckSource,
    reason: String
  ) {
    self.mandate = mandate
    self.source = source
    self.reason = reason
  }
}

/// Count of derived checks by enforcement class, plus unrepresented mandates, for legibility.
public struct ChecksManifestSummary: Codable, Equatable, Sendable {
  public let hookCount: Int
  public let commandCount: Int
  public let reviewCount: Int
  public let unrepresentedCount: Int

  public init(
    hookCount: Int,
    commandCount: Int,
    reviewCount: Int,
    unrepresentedCount: Int
  ) {
    self.hookCount = hookCount
    self.commandCount = commandCount
    self.reviewCount = reviewCount
    self.unrepresentedCount = unrepresentedCount
  }
}

/// Deterministic, schema-validated set of checks derived from a resolved contract.
///
/// Read-only in Phase 1a: this describes what *could* be enforced and at what ceiling.
/// It emits no host artifacts and performs no enforcement — projection into a concrete
/// host (Claude Code deny-hooks, etc.) is Phase 1b.
public struct ChecksManifest: Codable, Equatable, Sendable {
  public let sessionId: String?
  public let personaId: String
  public let directiveId: String?
  public let checks: [DerivedCheck]
  public let unrepresentedMandates: [UnrepresentedMandate]
  public let summary: ChecksManifestSummary

  public init(
    sessionId: String?,
    personaId: String,
    directiveId: String?,
    checks: [DerivedCheck],
    unrepresentedMandates: [UnrepresentedMandate],
    summary: ChecksManifestSummary
  ) {
    self.sessionId = sessionId
    self.personaId = personaId
    self.directiveId = directiveId
    self.checks = checks
    self.unrepresentedMandates = unrepresentedMandates
    self.summary = summary
  }

  /// Returns the class-1 hook check that forbids a host-neutral action class, if any.
  ///
  /// Host-neutral by design: it knows nothing about concrete host tools. A host adapter maps
  /// its own tool vocabulary to an action class, then asks the manifest here — keeping the
  /// deny decision in the neutral core and host knowledge in the adapter.
  public func hookCheck(denying actionClass: String) -> DerivedCheck? {
    checks.first { check in
      check.maxClass == CheckClass.hook.rawValue
        && (check.rule.deniedActionClasses ?? []).contains(actionClass)
    }
  }
}

/// Derives a deterministic ``ChecksManifest`` from an already-resolved session contract.
///
/// Grounded strictly in existing structured contract data:
/// - **class-1 (hook)** from the persona's `forbiddenCapabilities` over the closed
///   ``SkillCapability`` vocabulary. Forbidding `edit-files` and `run-commands`
///   independently denies file-mutation *and* command-execution, so a read-only stance
///   closes the shell-bypass path by construction — no special-casing.
/// - **class-2 (command)** from `directive.verification` entries whose kind is `command`.
/// - **class-3 (review)** from `directive.steps` marked `requiresReview` and the remaining
///   (non-command) `directive.verification` entries — the structured but not
///   machine-enforceable review gates.
///
/// Mandates PK cannot turn into a check are reported in `unrepresentedMandates` rather than
/// dropped: forbidden capabilities outside the known vocabulary (no machine rule derivable)
/// and prose persona non-goals (the class-3 readiness gap). PK never invents structure from
/// prose here; it names what it cannot yet enforce.
///
/// Check identifiers are content-derived (a slug of the source text) so they stay stable when
/// unrelated verification items or steps are reordered — enforcement projected in Phase 1b can
/// key off them without silently repointing.
public enum ChecksManifestDeriver {
  /// Derives the manifest from a full resolved contract result.
  public static func derive(from result: SessionContractResult) -> ChecksManifest {
    derive(
      sessionId: result.sessionId,
      persona: result.persona,
      directive: result.directive
    )
  }

  /// Core derivation over the two entities a manifest depends on.
  static func derive(
    sessionId: String?,
    persona: Persona,
    directive: Directive?
  ) -> ChecksManifest {
    let (hookChecks, unknownCapabilities) = deriveHookChecks(persona: persona)
    let commandChecks = deriveCommandChecks(directive: directive)
    let reviewChecks = deriveReviewChecks(directive: directive)
    let unrepresented = deriveUnrepresentedMandates(
      persona: persona,
      unknownCapabilities: unknownCapabilities
    )

    let checks = hookChecks + commandChecks + reviewChecks

    return ChecksManifest(
      sessionId: sessionId,
      personaId: persona.id,
      directiveId: directive?.id,
      checks: checks,
      unrepresentedMandates: unrepresented,
      summary: ChecksManifestSummary(
        hookCount: hookChecks.count,
        commandCount: commandChecks.count,
        reviewCount: reviewChecks.count,
        unrepresentedCount: unrepresented.count
      )
    )
  }

  /// Class-1 hook checks (one per known forbidden capability, in vocabulary order) plus the
  /// sorted, de-duplicated set of forbidden capabilities outside the known vocabulary.
  private static func deriveHookChecks(
    persona: Persona
  ) -> (checks: [DerivedCheck], unknownCapabilities: [String]) {
    let forbidden = Set(persona.forbiddenCapabilities ?? [])

    let checks =
      SkillCapability.allCases
      .filter { forbidden.contains($0.rawValue) }
      .sorted { $0.rawValue < $1.rawValue }
      .map { capability -> DerivedCheck in
        let actionClasses = deniedActionClasses(for: capability)

        return DerivedCheck(
          id: "capability-deny.\(capability.rawValue)",
          mandate: "Forbidden capability '\(capability.rawValue)': deny \(actionClasses.joined(separator: ", ")) actions.",
          maxClass: CheckClass.hook.rawValue,
          rule: CheckRule(
            kind: .capabilityDeny,
            deniedCapability: capability.rawValue,
            deniedActionClasses: actionClasses
          ),
          source: CheckSource(
            sourceType: "persona",
            sourceId: persona.id,
            field: "forbiddenCapabilities"
          ),
          hostNotes: [
            "Reaches class 'hook' only on hosts with pre-action deny hooks (for example Claude Code PreToolUse).",
            "Degrades to class 'review' on hosts without deny hooks; PK reports the reachable ceiling per host at projection time.",
          ]
        )
      }

    let unknownCapabilities =
      Set(forbidden.filter { SkillCapability(rawValue: $0) == nil })
      .sorted()

    return (checks, unknownCapabilities)
  }

  /// Class-2 command checks from `directive.verification` entries whose kind is `command`.
  private static func deriveCommandChecks(directive: Directive?) -> [DerivedCheck] {
    guard let directive else {
      return []
    }

    var idCounts: [String: Int] = [:]

    return
      directive.verification
      .filter { $0.kind == "command" }
      .map { item in
        DerivedCheck(
          id: uniqueID(prefix: "command", text: item.text, counts: &idCounts),
          mandate: "Verification command must pass: '\(item.text)'.",
          maxClass: CheckClass.command.rawValue,
          rule: CheckRule(kind: .command, command: item.text),
          source: CheckSource(sourceType: "directive", sourceId: directive.id, field: "verification"),
          hostNotes: [
            "Reaches class 'command' on any host that can run the command and gate on its exit code.",
            "The command outcome is environment-dependent and is not part of PK's deterministic core.",
          ]
        )
      }
  }

  /// Class-3 review checks: `requiresReview` steps first, then non-command verification items.
  private static func deriveReviewChecks(directive: Directive?) -> [DerivedCheck] {
    guard let directive else {
      return []
    }

    var idCounts: [String: Int] = [:]
    let hostNotes = [
      "No deterministic or command enforcement is available; the ceiling is class 'review' (human or review-agent sign-off).",
      "This is the class-3 readiness gap: the mandate is represented, not machine-enforced.",
    ]

    var checks: [DerivedCheck] = []

    for step in directive.steps where step.requiresReview == true {
      checks.append(
        DerivedCheck(
          id: uniqueID(prefix: "review", text: step.text, counts: &idCounts),
          mandate: "Review gate (step) — \(step.text).",
          maxClass: CheckClass.review.rawValue,
          rule: CheckRule(kind: .review, criterion: step.text),
          source: CheckSource(sourceType: "directive", sourceId: directive.id, field: "steps"),
          hostNotes: hostNotes
        )
      )
    }

    for item in directive.verification where item.kind != "command" {
      checks.append(
        DerivedCheck(
          id: uniqueID(prefix: "review", text: item.text, counts: &idCounts),
          mandate: "Review gate (\(item.kind)) — \(item.text).",
          maxClass: CheckClass.review.rawValue,
          rule: CheckRule(kind: .review, criterion: item.text),
          source: CheckSource(sourceType: "directive", sourceId: directive.id, field: "verification"),
          hostNotes: hostNotes
        )
      )
    }

    return checks
  }

  /// Mandates PK found but could not turn into a check, reported instead of dropped.
  private static func deriveUnrepresentedMandates(
    persona: Persona,
    unknownCapabilities: [String]
  ) -> [UnrepresentedMandate] {
    var items: [UnrepresentedMandate] = []

    for capability in unknownCapabilities {
      items.append(
        UnrepresentedMandate(
          mandate: "Forbidden capability '\(capability)'.",
          source: CheckSource(
            sourceType: "persona",
            sourceId: persona.id,
            field: "forbiddenCapabilities"
          ),
          reason:
            "Capability is outside the known vocabulary (\(SkillCapability.vocabulary.joined(separator: ", "))); no machine rule can be derived."
        )
      )
    }

    for nonGoal in persona.nonGoals {
      items.append(
        UnrepresentedMandate(
          mandate: nonGoal,
          source: CheckSource(sourceType: "persona", sourceId: persona.id, field: "nonGoals"),
          reason: "Prose non-goal with no structured enforcement source (class-3 readiness gap)."
        )
      )
    }

    return items
  }

  /// Builds a content-stable, unique id: `<prefix>.<slug>`, suffixed `-2`, `-3`, … on collision.
  private static func uniqueID(prefix: String, text: String, counts: inout [String: Int]) -> String {
    let base = "\(prefix).\(slug(text))"
    let occurrence = (counts[base] ?? 0) + 1
    counts[base] = occurrence

    return occurrence == 1 ? base : "\(base)-\(occurrence)"
  }

  /// Lowercased, hyphen-separated slug of alphanumeric runs; stable and host-neutral.
  private static func slug(_ text: String) -> String {
    var result = ""
    var pendingSeparator = false

    for character in text.lowercased() {
      if character.isLetter || character.isNumber {
        if pendingSeparator, !result.isEmpty {
          result.append("-")
        }
        result.append(character)
        pendingSeparator = false
      } else {
        pendingSeparator = true
      }
    }

    return result.isEmpty ? "item" : result
  }

  /// Maps a host-neutral capability to the action classes a host must block to honor it.
  private static func deniedActionClasses(for capability: SkillCapability) -> [String] {
    switch capability {
    case .readOnlyInspection:
      return ["inspection"]
    case .editFiles:
      return ["file-mutation"]
    case .runCommands:
      return ["command-execution"]
    case .networkAccess:
      return ["network-egress"]
    case .autonomousLoop:
      return ["unattended-iteration"]
    }
  }
}
