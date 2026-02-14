import Foundation

/// Renders a deterministic dependency graph for a resolved PersonaKit session.
struct GraphPrinter {
  /// Builds the text graph output for a resolved session and optional kit overrides.
  ///
  /// - Parameters:
  ///   - resolvedSession: The fully resolved session graph inputs.
  ///   - kitOverrides: User-specified kit overrides applied for this render.
  /// - Returns: A newline-terminated graph representation.
  static func render(resolvedSession: ResolvedSession, kitOverrides: [String]) -> String {
    let persona = resolvedSession.persona
    let directive = resolvedSession.directive
    let overrides = uniqueSorted(kitOverrides)
    let overrideDisplay = overrides.isEmpty ? "none" : overrides.joined(separator: ", ")
    let appliedKits = resolvedSession.kits.sorted { $0.id < $1.id }
    let kitById = Dictionary(uniqueKeysWithValues: appliedKits.map { ($0.id, $0) })
    let defaultKitIds = uniqueSorted(persona.defaultKitIds)
    let defaultKitLines = defaultKitIds.map { kitId in
      if let kit = kitById[kitId] {
        return "- \(formatLine(id: kit.id, name: kit.name))"
      }

      return "- \(kitId)"
    }
    let appliedKitLines = appliedKits.map { "- \(formatLine(id: $0.id, name: $0.name))" }
    let directiveIntentLines = uniqueSorted(directive.requiresIntentTemplateIds).map {
      "- intent:\($0)"
    }
    let directiveSkillLines = uniqueSorted(directive.requiresSkillIds).map { "- skill:\($0)" }
    let kitsToEssentialsLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let essentials = uniqueSorted(kit.essentialIds)
      lines.append(contentsOf: essentials.map { "  - essential:\($0)" })
      return lines
    }
    let kitsToIntentLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let intents = uniqueSorted(kit.intentTemplateIds ?? [])
      lines.append(contentsOf: intents.map { "  - intent:\($0)" })
      return lines
    }
    let kitsToSkillLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let skills = uniqueSorted(kit.skillIds ?? [])
      lines.append(contentsOf: skills.map { "  - skill:\($0)" })
      return lines
    }
    let resolvedEssentialLines = resolvedSession.essentials.map { $0.id }.sorted().map { "- \($0)" }
    let resolvedIntentLines = resolvedSession.intents.map { $0.id }.sorted().map { "- \($0)" }
    let resolvedSkillLines = resolvedSession.skills.map { $0.id }.sorted().map { "- \($0)" }
    var lines = [String]()
    var finalLines = ["Essentials:"]

    lines.append("PersonaKit-Graph-Version: 1")
    lines.append("")
    lines.append("# Graph")
    lines.append("Persona: \(formatLine(id: persona.id, name: persona.name))")
    lines.append("Directive: \(formatLine(id: directive.id, name: directive.title))")
    lines.append("Kit overrides: \(overrideDisplay)")

    appendSection("## Persona default kits", body: defaultKitLines, to: &lines)
    appendSection("## Applied kits (after overrides)", body: appliedKitLines, to: &lines)
    appendSection("## Kits \u{2192} Essentials", body: kitsToEssentialsLines, to: &lines)
    appendSection("## Kits \u{2192} Intent templates", body: kitsToIntentLines, to: &lines)
    appendSection("## Kits \u{2192} Skills", body: kitsToSkillLines, to: &lines)
    appendSection("## Directive \u{2192} Intent templates", body: directiveIntentLines, to: &lines)
    appendSection("## Directive \u{2192} Skills", body: directiveSkillLines, to: &lines)

    finalLines.append(contentsOf: resolvedEssentialLines)
    finalLines.append("Intents:")
    finalLines.append(contentsOf: resolvedIntentLines)
    finalLines.append("Skills:")
    finalLines.append(contentsOf: resolvedSkillLines)
    appendSection("## Final resolved sets", body: finalLines, to: &lines)

    return lines.joined(separator: "\n") + "\n"
  }

  /// Formats an id/name pair for graph display, omitting the separator when name is empty.
  private static func formatLine(id: String, name: String?) -> String {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !trimmedName.isEmpty else {
      return id
    }

    return "\(id) — \(trimmedName)"
  }

  /// Appends a section heading and its body lines, always separated by a blank line.
  private static func appendSection(_ heading: String, body: [String], to lines: inout [String]) {
    lines.append("")
    lines.append(heading)
    lines.append(contentsOf: body)
  }
}

/// De-duplicates and sorts ids to keep graph output stable across runs.
private func uniqueSorted(_ ids: [String]) -> [String] {
  return Set(ids).sorted()
}
