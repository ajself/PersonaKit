import Foundation

/// Errors produced while exporting a resolved PersonaKit session.
public enum ExportError: Error {
  /// Validation failed for one or more entities in the requested scopes.
  case validationFailed(ValidationResult)

  /// Session resolution failed after loading validated entities.
  case resolutionFailed(ResolverResolutionError)

  /// A referenced essential file could not be read or decoded.
  case readFailed(String)
}

/// Renders deterministic Markdown output for a Persona + Directive session.
public struct SessionExporter {
  /// Exports a session by treating `root` as the only active PersonaKit scope.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory that contains `Packs/` and optional `Sessions/`.
  ///   - personaId: The persona id to resolve.
  ///   - directiveId: The directive id to resolve.
  ///   - kitOverrides: Optional kit ids to apply in addition to persona defaults.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic Markdown session output.
  /// - Throws: ``ExportError`` when validation, resolution, or file reads fail.
  public static func export(
    root: URL,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    sessionId: String? = nil,
    targetPaths: [String] = [],
    referenceTags: [String] = [],
    fileManager: FileManager = .default
  ) throws -> String {
    try export(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      sessionId: sessionId,
      targetPaths: targetPaths,
      referenceTags: referenceTags,
      fileManager: fileManager
    )
  }

  /// Exports a session from already-resolved project/global scope inputs.
  ///
  /// - Parameters:
  ///   - scopes: Scope set used for validation, registry loading, and session resolution.
  ///   - personaId: The persona id to resolve.
  ///   - directiveId: The directive id to resolve.
  ///   - kitOverrides: Optional kit ids to apply in addition to persona defaults.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic Markdown session output.
  /// - Throws: ``ExportError`` when validation, resolution, or file reads fail.
  public static func export(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    sessionId: String? = nil,
    targetPaths: [String] = [],
    referenceTags: [String] = [],
    fileManager: FileManager = .default
  ) throws -> String {
    let validation = try Validator.validate(scopes: scopes, fileManager: fileManager)

    if !validation.errors.isEmpty {
      throw ExportError.validationFailed(validation)
    }

    let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
    let definition = SessionDefinition(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides.isEmpty ? nil : kitOverrides
    )
    let session: ResolvedSession

    do {
      session = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes,
        fileManager: fileManager
      )
    } catch let error as ResolverResolutionError {
      throw ExportError.resolutionFailed(error)
    }

    let essentials = try loadEssentials(session.essentials, fileManager: fileManager)
    let referenceInput = ReferenceSelectionInput(
      targetPaths: targetPaths,
      referenceTags: referenceTags
    )
    let matchedReferences = ReferenceSupport.resolveMatches(
      availableReferences: session.availableReferences,
      input: referenceInput
    )
    let expandedReferences: [ExpandedReferenceDocument]

    do {
      expandedReferences = try ReferenceSupport.loadExpandedDocuments(
        matches: matchedReferences,
        scopes: scopes,
        fileManager: fileManager
      )
    } catch let error as ReferenceResolutionError {
      throw ExportError.readFailed(error.message)
    }

    return renderSession(
      persona: session.persona,
      directive: session.directive,
      kits: session.kits.sorted { $0.id < $1.id },
      intents: session.intents.sorted { $0.id < $1.id },
      skills: session.skills.sorted { $0.id < $1.id },
      essentials: essentials,
      availableReferences: session.availableReferences.sorted { $0.id < $1.id },
      expandedReferences: expandedReferences,
      skillAuthorization: session.skillAuthorization,
      sessionId: sessionId
    )
  }

  /// Loads and normalizes essential Markdown files referenced by a resolved session.
  ///
  /// This helper sorts by essential id and ensures each document ends with a newline.
  private static func loadEssentials(
    _ essentials: [ResolvedEssential],
    fileManager: FileManager
  ) throws -> [ResolvedEssential] {
    return try SystemEssentials.sortResolvedEssentialsForResolvedOutput(essentials).map { essential in
      if var content = essential.content {
        if !content.hasSuffix("\n") {
          content.append("\n")
        }

        return ResolvedEssential(
          id: essential.id,
          url: essential.url,
          content: content,
          source: essential.source
        )
      }

      let data: Data

      do {
        data = try Data(contentsOf: essential.url)
      } catch {
        throw ExportError.readFailed("Failed to read essential: \(essential.id)")
      }

      guard var content = String(data: data, encoding: .utf8) else {
        throw ExportError.readFailed("Failed to decode essential: \(essential.id)")
      }

      if !content.hasSuffix("\n") {
        content.append("\n")
      }

      return ResolvedEssential(
        id: essential.id,
        url: essential.url,
        content: content,
        source: essential.source
      )
    }
  }

  /// Renders resolved session components into the canonical Markdown export format.
  private static func renderSession(
    persona: Persona,
    directive: Directive,
    kits: [Kit],
    intents: [IntentTemplate],
    skills: [Skill],
    essentials: [ResolvedEssential],
    availableReferences: [ResolvedReference],
    expandedReferences: [ExpandedReferenceDocument],
    skillAuthorization: ResolvedSkillAuthorization,
    sessionId: String?
  ) -> String {
    var output = ""

    func appendLine(_ line: String = "") {
      output.append(line)
      output.append("\n")
    }

    appendLine("PersonaKit-Output-Version: 1")
    appendLine()
    appendLine("# Persona")
    appendLine("Name: \(persona.name)")
    appendLine("Id: \(persona.id)")

    if !persona.summary.isEmpty {
      appendLine("Summary: \(persona.summary)")
    }

    appendListSection(
      title: "Responsibilities",
      items: persona.responsibilities,
      appendLine: appendLine
    )
    appendListSection(
      title: "Values",
      items: persona.values,
      appendLine: appendLine
    )
    appendListSection(
      title: "Non-goals",
      items: persona.nonGoals,
      appendLine: appendLine
    )

    let allowedSkills = persona.allowedSkillIds.sorted()
    appendListSection(
      title: "Allowed Skills",
      items: allowedSkills,
      appendLine: appendLine
    )

    let forbiddenSkills = persona.forbiddenSkillIds.sorted()
    appendListSection(
      title: "Forbidden Skills",
      items: forbiddenSkills,
      appendLine: appendLine
    )

    appendLine()
    appendLine("# Skill Contract")
    // Allowed/Forbidden are the persona inputs already shown under `# Persona`;
    // this section reports only the resolution outcome (what was authorized,
    // required, and any required-but-unauthorized gap).
    appendListSection(
      title: "Authorized Skills",
      items: skillAuthorization.authorizedSkillIds,
      appendLine: appendLine
    )
    appendListSection(
      title: "Required Skills",
      items: skillAuthorization.requiredSkillIds,
      appendLine: appendLine
    )
    appendListSection(
      title: "Unauthorized Required Skills",
      items: skillAuthorization.unauthorizedRequiredSkillIds,
      appendLine: appendLine
    )

    appendLine()
    appendLine("Authorized: \(skillAuthorization.isAuthorized)")

    if !skillAuthorization.failureReasons.isEmpty {
      appendListSection(
        title: "Failure Reasons",
        items: skillAuthorization.failureReasons,
        appendLine: appendLine
      )
      appendLine()
      appendLine(
        "Hard Stop: Stop and re-ground before using any skill outside the resolved PersonaKit contract."
      )
    }

    appendLine()
    appendLine("# Applied Kits")

    for kit in kits {
      appendLine("- \(kit.name) (\(kit.id))")
    }

    appendLine()
    appendLine("# Available References")

    if availableReferences.isEmpty {
      appendLine("- none")
    } else {
      for reference in availableReferences {
        appendLine("## \(reference.id)")
        appendLine("Name: \(reference.name)")
        appendLine("Summary: \(reference.summary)")
        appendLine("Triggers: \(ReferenceSupport.triggerSummary(for: reference))")
        appendLine("Sources:")
        for source in reference.sources {
          appendLine("- \(source.sourceType.rawValue):\(source.sourceId) [\(source.field)]")
        }
      }
    }

    appendLine()
    appendLine("# Essentials")

    let orderedEssentials = SystemEssentials.sortResolvedEssentialsForResolvedOutput(essentials)

    for (index, essential) in orderedEssentials.enumerated() {
      appendLine("## \(essential.id)")
      appendLine()
      output.append(normalizeIncludedMarkdownBody(essential.content ?? ""))
      if index < orderedEssentials.count - 1 {
        appendLine()
      }
    }

    if !expandedReferences.isEmpty {
      appendLine()
      appendLine("# Expanded References")

      for (index, reference) in expandedReferences.enumerated() {
        appendLine("## \(reference.id)")
        appendLine("Name: \(reference.title)")
        appendLine("Summary: \(reference.match.summary)")
        appendLine("Matched Triggers:")
        for rule in reference.match.matchedRules {
          var ruleDetails: [String] = []
          if !rule.matchedPathGlobs.isEmpty {
            ruleDetails.append(
              "paths=\(rule.matchedPathGlobs.joined(separator: ", ")) => \(rule.matchedPaths.joined(separator: ", "))"
            )
          }
          if !rule.matchedReferenceTags.isEmpty {
            ruleDetails.append("referenceTags=\(rule.matchedReferenceTags.joined(separator: ", "))")
          }
          appendLine("- rule[\(rule.ruleIndex)]: \(ruleDetails.joined(separator: " + "))")
        }
        appendLine()
        output.append(normalizeIncludedMarkdownBody(reference.content))
        if index < expandedReferences.count - 1 {
          appendLine()
        }
      }
    }

    appendLine()
    appendLine("# Directive")
    appendLine("Title: \(directive.title)")
    appendLine("Id: \(directive.id)")
    appendLine("Goal: \(directive.goal)")

    if !directive.steps.isEmpty {
      appendLine()
      appendLine("Steps:")
      for (index, step) in directive.steps.enumerated() {
        var line = "\(index + 1). \(step.text)"
        if step.requiresReview == true {
          line += " (requires review)"
        }
        appendLine(line)
      }
    }

    appendListSection(
      title: "Acceptance Criteria",
      items: directive.acceptanceCriteria,
      appendLine: appendLine
    )

    if !directive.verification.isEmpty {
      appendLine()
      appendLine("Verification:")
      for item in directive.verification {
        appendLine("- \(item.kind): \(item.text)")
      }
    }

    let stopPoints = directive.steps.filter { $0.requiresReview == true }.map { $0.text }
    appendListSection(
      title: "Stop Points",
      items: stopPoints,
      appendLine: appendLine
    )

    if let workstream = directive.workstream {
      appendLine()
      appendLine("# Workstream")
      appendLine("Id: \(workstream.id)")
      appendLine("Phase: \(workstream.phase)")
      appendLine("Entry Session: \(workstream.entrySessionId)")

      if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId {
        appendLine("Required Closeout Session: \(requiredCloseoutSessionId)")
      }

      let nextSessionIds = workstream.nextSessionIds(fromSessionId: sessionId)
      appendListSection(
        title: "Next Sessions",
        items: nextSessionIds,
        appendLine: appendLine
      )

      appendLine()
      appendLine("Session Map:")
      for node in workstream.orderedNodes {
        appendLine("- \(node.phase): \(node.sessionId)")
      }
    }

    appendLine()
    appendLine("# Intent Templates")
    for intent in intents {
      appendLine("## \(intent.id)")
      appendLine("Name: \(intent.name)")
      appendLine("Id: \(intent.id)")
      appendLine("Description: \(intent.description)")

      if !intent.parameters.isEmpty {
        appendLine()
        appendLine("Parameters:")
        for parameter in intent.parameters {
          let requiredLabel = parameter.required ? "required" : "optional"
          appendLine("- \(parameter.name) (\(parameter.type), \(requiredLabel))")
        }
      }

      appendLine()
      appendLine("Risk:")
      appendLine("- Level: \(intent.risk.level)")
      appendLine("- Requires human review: \(intent.risk.requiresHumanReview)")
      if !intent.risk.notes.isEmpty {
        appendLine("- Notes:")
        for note in intent.risk.notes {
          appendLine("  - \(note)")
        }
      }

      let requiredSkills = intent.requiresSkillIds.sorted()
      appendListSection(
        title: "Required Skills",
        items: requiredSkills,
        appendLine: appendLine
      )

      let includedEssentials = intent.includesEssentialIds.sorted()
      appendListSection(
        title: "Included Essentials",
        items: includedEssentials,
        appendLine: appendLine
      )

      if intent.id != intents.last?.id {
        appendLine()
      }
    }

    appendLine()
    appendLine("# Skill Awareness")
    for skill in skills {
      appendLine("## \(skill.id)")
      appendLine("Name: \(skill.name)")
      appendLine("Id: \(skill.id)")
      appendLine("Description: \(skill.description)")

      if !skill.providedBy.isEmpty {
        appendLine()
        appendLine("Provided By:")
        for provider in skill.providedBy {
          appendLine("- \(provider)")
        }
      }

      appendLine()
      appendLine("Risk:")
      appendLine("- Level: \(skill.risk.level)")
      appendLine("- Requires human review: \(skill.risk.requiresHumanReview)")
      if !skill.risk.notes.isEmpty {
        appendLine("- Notes:")
        for note in skill.risk.notes {
          appendLine("  - \(note)")
        }
      }

      if !skill.notes.isEmpty {
        appendLine()
        appendLine("Notes:")
        for note in skill.notes {
          appendLine("- \(note)")
        }
      }

      if skill.id != skills.last?.id {
        appendLine()
      }
    }

    return output
  }

  private static func normalizeIncludedMarkdownBody(_ content: String) -> String {
    var lines = content.components(separatedBy: .newlines)

    guard let firstLine = lines.first,
      firstLine.hasPrefix("# "),
      !firstLine.hasPrefix("## ")
    else {
      return content
    }

    lines.removeFirst()

    while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
      lines.removeFirst()
    }

    var normalized = lines.joined(separator: "\n")

    if !normalized.isEmpty,
      !normalized.hasSuffix("\n")
    {
      normalized.append("\n")
    }

    return normalized
  }

  /// Appends a titled bullet list section when `items` is non-empty.
  private static func appendListSection(
    title: String,
    items: [String],
    appendLine: (String) -> Void
  ) {
    guard !items.isEmpty else { return }
    appendLine("")
    appendLine("\(title):")
    for item in items {
      appendLine("- \(item)")
    }
  }
}
