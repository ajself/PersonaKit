import Foundation

/// Errors produced while exporting a resolved PersonaKit session.
public enum ExportError: Error {
  /// Validation failed for one or more entities in the requested scopes.
  case validationFailed(ValidationResult)

  /// Session resolution failed after loading validated entities.
  case resolutionFailed(ResolverResolutionError)

  /// A referenced grounding-skill body file could not be read or decoded.
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
    skillTags: [String] = [],
    fileManager: FileManager = .default
  ) throws -> String {
    try export(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      sessionId: sessionId,
      targetPaths: targetPaths,
      skillTags: skillTags,
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
    skillTags: [String] = [],
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

    let triggerInput = SkillTriggerSelectionInput(
      targetPaths: targetPaths,
      skillTags: skillTags
    )
    let matchedGroundingSkills = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: session.availableGroundingSkills,
      input: triggerInput
    )
    let expandedGroundingSkills: [ExpandedGroundingSkillDocument]

    do {
      expandedGroundingSkills = try GroundingSkillSupport.loadExpandedDocuments(
        matches: matchedGroundingSkills,
        scopes: scopes,
        fileManager: fileManager
      )
    } catch let error as GroundingSkillResolutionError {
      throw ExportError.readFailed(error.message)
    }

    return renderSession(
      persona: session.persona,
      directive: session.directive,
      kits: session.kits.sorted { $0.id < $1.id },
      skills: session.skills.sorted { $0.id < $1.id },
      availableGroundingSkills: session.availableGroundingSkills.sorted { $0.id < $1.id },
      expandedGroundingSkills: expandedGroundingSkills,
      skillAuthorization: session.skillAuthorization,
      sessionId: sessionId
    )
  }

  /// Renders resolved session components into the canonical Markdown export format.
  private static func renderSession(
    persona: Persona,
    directive: Directive,
    kits: [Kit],
    skills: [Skill],
    availableGroundingSkills: [ResolvedGroundingSkill],
    expandedGroundingSkills: [ExpandedGroundingSkillDocument],
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

    appendLine()
    appendLine("Activation Contract: \(SystemFramings.personaActivationFraming)")

    appendListSection(
      title: "Environment",
      items: persona.environment ?? [],
      appendLine: appendLine
    )
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
    appendLine("Authorization Contract: \(SystemFramings.skillAuthorizationFraming)")
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
    appendLine("# Available Skills")

    if availableGroundingSkills.isEmpty {
      appendLine("- none")
    } else {
      for groundingSkill in availableGroundingSkills {
        appendLine("## \(groundingSkill.id)")
        appendLine("Name: \(groundingSkill.name)")
        appendLine("Description: \(groundingSkill.description)")
        appendLine("Triggers: \(GroundingSkillSupport.triggerSummary(for: groundingSkill))")
        appendLine("Sources:")
        for source in groundingSkill.sources {
          appendLine("- \(source.sourceType.rawValue):\(source.sourceId) [\(source.field)]")
        }
      }
    }

    if !expandedGroundingSkills.isEmpty {
      appendLine()
      appendLine("# Expanded Skills")

      for (index, groundingSkill) in expandedGroundingSkills.enumerated() {
        appendLine("## \(groundingSkill.id)")
        appendLine("Name: \(groundingSkill.title)")
        appendLine("Description: \(groundingSkill.match.description)")
        appendLine("Matched Triggers:")
        for rule in groundingSkill.match.matchedRules {
          var ruleDetails: [String] = []
          if !rule.matchedPathGlobs.isEmpty {
            ruleDetails.append(
              "paths=\(rule.matchedPathGlobs.joined(separator: ", ")) => \(rule.matchedPaths.joined(separator: ", "))"
            )
          }
          if !rule.matchedSkillTags.isEmpty {
            ruleDetails.append("skillTags=\(rule.matchedSkillTags.joined(separator: ", "))")
          }
          let ruleSummary = ruleDetails.isEmpty ? "always-on" : ruleDetails.joined(separator: " + ")
          appendLine("- rule[\(rule.ruleIndex)]: \(ruleSummary)")
        }
        appendLine()
        output.append(normalizeIncludedMarkdownBody(groundingSkill.content))
        if index < expandedGroundingSkills.count - 1 {
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

    if !directive.parameters.isEmpty {
      appendLine()
      appendLine("Parameters:")
      for parameter in directive.parameters {
        let requiredLabel = parameter.required ? "required" : "optional"
        appendLine("- \(parameter.name) (\(parameter.type), \(requiredLabel))")
      }
    }

    if let risk = directive.risk {
      appendLine()
      appendLine("Risk:")
      appendLine("- Level: \(risk.level)")
      appendLine("- Requires human review: \(risk.requiresHumanReview)")
      if !risk.notes.isEmpty {
        appendLine("- Notes:")
        for note in risk.notes {
          appendLine("  - \(note)")
        }
      }
    }

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

    let checksManifest = ChecksManifestDeriver.derive(
      sessionId: sessionId,
      persona: persona,
      directive: directive
    )
    appendLine()
    for line in ChecksManifestMarkdownRenderer.boundariesLines(checksManifest) {
      appendLine(line)
    }

    appendLine()
    appendLine("# Skill Awareness")
    for skill in skills {
      appendLine("## \(skill.id)")
      appendLine("Name: \(skill.name)")
      appendLine("Id: \(skill.id)")
      appendLine("Description: \(skill.description)")

      if let providedBy = skill.providedBy, !providedBy.isEmpty {
        appendLine()
        appendLine("Provided By:")
        for provider in providedBy {
          appendLine("- \(provider)")
        }
      }

      if let risk = skill.risk {
        appendLine()
        appendLine("Risk:")
        appendLine("- Level: \(risk.level)")
        appendLine("- Requires human review: \(risk.requiresHumanReview)")
        if !risk.notes.isEmpty {
          appendLine("- Notes:")
          for note in risk.notes {
            appendLine("  - \(note)")
          }
        }
      }

      if let notes = skill.notes, !notes.isEmpty {
        appendLine()
        appendLine("Notes:")
        for note in notes {
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
