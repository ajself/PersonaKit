import Foundation

/// Renders a deterministic dependency graph for a resolved PersonaKit session.
public struct GraphPrinter {
  /// Builds the text graph output for a resolved session and optional kit overrides.
  ///
  /// - Parameters:
  ///   - resolvedSession: The fully resolved session graph inputs.
  ///   - kitOverrides: User-specified kit overrides applied for this render.
  /// - Returns: A newline-terminated graph representation.
  public static func render(resolvedSession: ResolvedSession, kitOverrides: [String]) -> String {
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
    let directiveSkillLines = uniqueSorted(directive.requiresSkillIds).map { "- skill:\($0)" }
    let directiveReferenceLines = uniqueSorted(directive.referenceIds ?? []).map { "- reference:\($0)" }
    let kitsToEssentialsLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let essentials = uniqueSorted(kit.essentialIds)
      lines.append(contentsOf: essentials.map { "  - essential:\($0)" })
      return lines
    }
    let kitsToSkillLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let skills = uniqueSorted(kit.skillIds ?? [])
      lines.append(contentsOf: skills.map { "  - skill:\($0)" })
      return lines
    }
    let kitsToReferenceLines = appliedKits.flatMap { kit -> [String] in
      var lines: [String] = [kit.id]
      let references = uniqueSorted(kit.referenceIds ?? [])
      lines.append(contentsOf: references.map { "  - reference:\($0)" })
      return lines
    }
    let resolvedEssentialLines =
      SystemEssentials
      .sortEssentialIdsForResolvedOutput(resolvedSession.essentials.map(\.id))
      .map { "- \($0)" }
    let resolvedReferenceLines = resolvedSession.availableReferences.map(\.id).sorted().map { "- \($0)" }
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
    appendSection("## Kits \u{2192} References", body: kitsToReferenceLines, to: &lines)
    appendSection("## Kits \u{2192} Skills", body: kitsToSkillLines, to: &lines)
    appendSection("## Directive \u{2192} References", body: directiveReferenceLines, to: &lines)
    appendSection("## Directive \u{2192} Skills", body: directiveSkillLines, to: &lines)
    appendSection(
      "## Skill Contract",
      body: skillContractLines(for: resolvedSession.skillAuthorization),
      to: &lines
    )
    if directive.workstream != nil {
      appendSection(
        "## Workstream",
        body: workstreamLines(for: directive),
        to: &lines
      )
    }

    finalLines.append(contentsOf: resolvedEssentialLines)
    finalLines.append("References:")
    finalLines.append(contentsOf: resolvedReferenceLines)
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

private func skillContractLines(for contract: ResolvedSkillAuthorization) -> [String] {
  var lines = [
    "Allowed Skills:"
  ]

  lines.append(contentsOf: contract.allowedSkillIds.map { "  - \($0)" })
  lines.append("Forbidden Skills:")
  lines.append(contentsOf: contract.forbiddenSkillIds.map { "  - \($0)" })
  lines.append("Authorized Skills:")
  lines.append(contentsOf: contract.authorizedSkillIds.map { "  - \($0)" })
  lines.append("Required Skills:")
  lines.append(contentsOf: contract.requiredSkillIds.map { "  - \($0)" })
  lines.append("Unauthorized Required Skills:")
  lines.append(contentsOf: contract.unauthorizedRequiredSkillIds.map { "  - \($0)" })
  lines.append("Authorized: \(contract.isAuthorized)")

  if !contract.failureReasons.isEmpty {
    lines.append("Failure Reasons:")
    lines.append(contentsOf: contract.failureReasons.map { "  - \($0)" })
  }

  return lines
}

private func workstreamLines(for directive: Directive) -> [String] {
  guard let workstream = directive.workstream else {
    return []
  }

  var lines: [String] = [
    "Id: \(workstream.id)",
    "Phase: \(workstream.phase)",
    "Entry Session: \(workstream.entrySessionId)",
  ]

  if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId {
    lines.append("Required Closeout Session: \(requiredCloseoutSessionId)")
  }

  lines.append("Nodes:")
  lines.append(contentsOf: workstream.orderedNodes.map { "  - \($0.phase): \($0.sessionId)" })
  lines.append("Edges:")
  lines.append(
    contentsOf: workstream.orderedEdges.map {
      "  - \($0.fromSessionId) -> \($0.toSessionId) [\($0.kind)]"
    }
  )

  return lines
}

/// De-duplicates and sorts ids to keep graph output stable across runs.
private func uniqueSorted(_ ids: [String]) -> [String] {
  return Set(ids).sorted()
}
