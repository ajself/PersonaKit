import Foundation

/// Renders a ``ChecksManifest`` as the export's `# Boundaries` section.
///
/// The manifest is the single deriver; this is one of its two renderers (the other is the
/// JSON emitted by `personakit checks`). Markdown is a host-neutral display format, so the
/// core stays host-agnostic — only concrete enforcement projection (Phase 1b) is host-specific.
///
/// `# Boundaries` is the enforcement-projection index: for every guardrail it states the
/// strongest class it can reach and why, keyed by the manifest's stable id and pointing back
/// at its source rather than re-quoting whole prose. It does not restate the named-skill axis
/// (`# Persona` / `# Skill Contract`), which is orthogonal to the capability axis class-1
/// derives from.
enum ChecksManifestMarkdownRenderer {
  /// The `# Boundaries` section as export lines (header through the last bullet, no surrounding
  /// blank lines — the exporter owns section spacing). Deterministic: classes render 1→2→3,
  /// checks sort by id within each class, and unrepresented mandates keep the manifest's order.
  static func boundariesLines(_ manifest: ChecksManifest) -> [String] {
    var lines: [String] = []
    lines.append("# Boundaries")
    lines.append(
      "Derived enforcement view: each guardrail tagged with the strongest enforcement class it can reach; a host that lacks the mechanism degrades it. PersonaKit enforces none of this by itself."
    )

    appendClass(
      &lines,
      manifest: manifest,
      checkClass: .hook,
      label: "Class 1 — hook (deterministic deny)"
    )
    appendClass(
      &lines,
      manifest: manifest,
      checkClass: .command,
      label: "Class 2 — command (exit-code gate)"
    )
    appendClass(
      &lines,
      manifest: manifest,
      checkClass: .review,
      label: "Class 3 — review (human or agent sign-off)"
    )

    if !manifest.unrepresentedMandates.isEmpty {
      lines.append("")
      lines.append("Not yet checkable (represented, not enforced):")
      for item in manifest.unrepresentedMandates {
        lines.append("- \(item.mandate) — \(provenance(item.source))")
      }
    }

    return lines
  }

  /// Appends one class group: an inline `: none` when empty, otherwise a header line and one
  /// sorted-by-id bullet per check. The three classes always render so the full enforcement
  /// ladder — including its gaps — stays visible.
  private static func appendClass(
    _ lines: inout [String],
    manifest: ChecksManifest,
    checkClass: CheckClass,
    label: String
  ) {
    let checks =
      manifest.checks
      .filter { $0.maxClass == checkClass.rawValue }
      .sorted { $0.id < $1.id }

    guard !checks.isEmpty else {
      lines.append("\(label): none")
      return
    }

    lines.append("\(label):")
    for check in checks {
      lines.append("- \(check.id) — \(displayRule(check.rule)) — \(provenance(check.source))")
    }
  }

  /// Short, structured rendering of a rule — never the manifest's verbose `mandate` sentence.
  private static func displayRule(_ rule: CheckRule) -> String {
    switch rule.kind {
    case "capability-deny":
      return "deny \((rule.deniedActionClasses ?? []).joined(separator: ", "))"
    case "command":
      return "`\(rule.command ?? "")`"
    case "review":
      return rule.criterion ?? ""
    default:
      return rule.kind
    }
  }

  /// Back-pointer provenance, mirroring the `# Available Skills` Sources style: `entity:id [field]`.
  private static func provenance(_ source: CheckSource) -> String {
    "\(source.sourceType):\(source.sourceId) [\(source.field)]"
  }
}
