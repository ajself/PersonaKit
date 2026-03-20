import ContextCore
import Foundation
import MCP

extension MCPToolService {
  func explainEntityTool(input: MCPEntityArguments) throws -> String {
    let registry = try loadRegistry()

    switch input.entityType {
    case .persona:
      guard let persona = registry.personasById[input.id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .persona, id: input.id))
      }
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: PersonaExplainData(
            name: persona.name,
            summary: persona.summary,
            defaultKitIds: mcpUniqueSorted(persona.defaultKitIds),
            allowedSkillIds: mcpUniqueSorted(persona.allowedSkillIds),
            forbiddenSkillIds: mcpUniqueSorted(persona.forbiddenSkillIds),
            responsibilitiesCount: persona.responsibilities.count,
            valuesCount: persona.values.count,
            nonGoalsCount: persona.nonGoals.count
          )
        )
      )
    case .directive:
      guard let directive = registry.directivesById[input.id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .directive, id: input.id))
      }
      let reviewStepCount = directive.steps.filter { $0.requiresReview == true }.count
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: DirectiveExplainData(
            title: directive.title,
            goal: directive.goal,
            requiredIntentIds: mcpUniqueSorted(directive.requiresIntentTemplateIds),
            requiredSkillIds: mcpUniqueSorted(directive.requiresSkillIds),
            stepsCount: directive.steps.count,
            reviewStepCount: reviewStepCount,
            workstream: directive.workstream.map(mcpDirectiveExplainWorkstreamData)
          )
        )
      )
    case .kit:
      guard let kit = registry.kitsById[input.id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .kit, id: input.id))
      }
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: KitExplainData(
            name: kit.name,
            summary: kit.summary,
            essentialIds: mcpUniqueSorted(kit.essentialIds),
            intentTemplateIds: mcpUniqueSorted(kit.intentTemplateIds ?? []),
            skillIds: mcpUniqueSorted(kit.skillIds ?? [])
          )
        )
      )
    case .intent:
      guard let intent = registry.intentTemplatesById[input.id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .intent, id: input.id))
      }
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: IntentExplainData(
            name: intent.name,
            description: intent.description,
            parameterConstraints: intent.parameterConstraints?.map(mcpParameterConstraintSummary) ?? [],
            includesEssentialIds: mcpUniqueSorted(intent.includesEssentialIds),
            requiresSkillIds: mcpUniqueSorted(intent.requiresSkillIds),
            riskLevel: intent.risk.level,
            requiresHumanReview: intent.risk.requiresHumanReview
          )
        )
      )
    case .skill:
      guard let skill = registry.skillsById[input.id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .skill, id: input.id))
      }
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: SkillExplainData(
            name: skill.name,
            description: skill.description,
            providedBy: mcpUniqueSorted(skill.providedBy),
            riskLevel: skill.risk.level,
            requiresHumanReview: skill.risk.requiresHumanReview,
            notesCount: skill.notes.count
          )
        )
      )
    case .session:
      let session = try loadSession(id: input.id)
      let personaExists = registry.personasById[session.personaId] != nil
      let directiveExists = registry.directivesById[session.directiveId] != nil
      let missingKits = mcpUniqueSorted((session.kitOverrides ?? []).filter { registry.kitsById[$0] == nil })
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: SessionExplainData(
            personaId: session.personaId,
            directiveId: session.directiveId,
            kitOverrides: mcpUniqueSorted(session.kitOverrides ?? []),
            personaExists: personaExists,
            directiveExists: directiveExists,
            missingKitOverrides: missingKits
          )
        )
      )
    case .essential:
      guard let fileURL = mcpResolveEssentialURL(id: input.id, scopes: scopes, fileManager: .default)
      else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .essential, id: input.id))
      }
      let text: String
      do {
        text = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw MCPError.internalError("Failed to read essential \(input.id).")
      }
      return try mcpEncodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: EssentialExplainData(
            resolvedPath: fileURL.path,
            lineCount: mcpLineCount(text),
            byteCount: text.utf8.count
          )
        )
      )
    }
  }

  func compareEntitiesTool(input: MCPCompareArguments) throws -> String {
    let registry = try loadRegistry()
    let left = try comparableSnapshot(type: input.entityType, id: input.leftId, registry: registry)
    let right = try comparableSnapshot(type: input.entityType, id: input.rightId, registry: registry)

    let scalarKeys = Set(left.scalars.keys).union(right.scalars.keys).sorted()
    let scalarMatches = scalarKeys.filter { left.scalars[$0] == right.scalars[$0] }
    let scalarDifferences = scalarKeys.compactMap { key -> CompareScalarDifference? in
      let leftValue = left.scalars[key] ?? ""
      let rightValue = right.scalars[key] ?? ""
      guard leftValue != rightValue else {
        return nil
      }
      return CompareScalarDifference(field: key, left: leftValue, right: rightValue)
    }

    let listKeys = Set(left.lists.keys).union(right.lists.keys).sorted()
    let listMatches = listKeys.filter { left.lists[$0] == right.lists[$0] }
    let listDifferences = listKeys.compactMap { key -> CompareListDifference? in
      let leftValues = left.lists[key] ?? []
      let rightValues = right.lists[key] ?? []
      guard leftValues != rightValues else {
        return nil
      }

      let leftSet = Set(leftValues)
      let rightSet = Set(rightValues)
      let shared = leftSet.intersection(rightSet).sorted()
      let onlyLeft = leftSet.subtracting(rightSet).sorted()
      let onlyRight = rightSet.subtracting(leftSet).sorted()

      return CompareListDifference(
        field: key,
        shared: shared,
        onlyLeft: onlyLeft,
        onlyRight: onlyRight
      )
    }

    return try mcpEncodeToolJSON(
      ComparePayload(
        entityType: input.entityType.rawValue,
        leftId: input.leftId,
        rightId: input.rightId,
        scalarMatches: scalarMatches,
        scalarDifferences: scalarDifferences,
        listMatches: listMatches,
        listDifferences: listDifferences
      )
    )
  }

  func recommendSessionTool(input: MCPRecommendArguments) throws -> String {
    let registry = try loadRegistry()
    let sessions = try mcpListSessions(scopes: scopes, fileManager: .default)

    guard !sessions.isEmpty else {
      throw MCPError.invalidParams(
        mcpWithRecoveryHint(
          "No session files found in active scopes.",
          hint: "Create at least one Sessions/*.session.json file in the active PersonaKit scope."
        )
      )
    }

    let goalTerms = mcpTokenSet(input.goal)
    let recommendations = sessions.compactMap { session -> SessionRecommendation? in
      guard let persona = registry.personasById[session.personaId],
        let directive = registry.directivesById[session.directiveId]
      else {
        return nil
      }

      let personaTerms = mcpMatchedTerms(
        goalTerms: goalTerms,
        text: [
          persona.id,
          persona.name,
          persona.summary,
          persona.responsibilities.joined(separator: " "),
          persona.values.joined(separator: " "),
        ].joined(separator: " ")
      )

      let directiveTerms = mcpMatchedTerms(
        goalTerms: goalTerms,
        text: [
          directive.id,
          directive.title,
          directive.goal,
          directive.acceptanceCriteria.joined(separator: " "),
          directive.steps.map(\.text).joined(separator: " "),
        ].joined(separator: " ")
      )

      let sessionTerms = mcpMatchedTerms(goalTerms: goalTerms, text: session.id)

      let score = personaTerms.count * 3 + directiveTerms.count * 2 + sessionTerms.count

      return SessionRecommendation(
        sessionId: session.id,
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: mcpUniqueSorted(session.kitOverrides ?? []),
        score: score,
        matchedGoalTerms: mcpUniqueSorted(personaTerms + directiveTerms + sessionTerms),
        termMatches: SessionRecommendationTermMatches(
          persona: personaTerms,
          directive: directiveTerms,
          session: sessionTerms
        )
      )
    }
    .sorted {
      if $0.score != $1.score {
        return $0.score > $1.score
      }
      return $0.sessionId < $1.sessionId
    }

    let selected = Array(recommendations.prefix(input.limit))

    return try mcpEncodeToolJSON(
      SessionRecommendationPayload(
        goal: input.goal,
        goalTerms: goalTerms,
        consideredSessions: sessions.map(\.id).sorted(),
        policy: SessionRecommendationPolicy(),
        recommendations: selected
      )
    )
  }

  func comparableSnapshot(
    type: MCPEntityType,
    id: String,
    registry: Registry
  ) throws -> EntityComparableSnapshot {
    switch type {
    case .persona:
      guard let persona = registry.personasById[id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .persona, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": persona.id,
          "name": persona.name,
          "summary": persona.summary,
          "version": persona.version,
        ],
        lists: [
          "defaultKitIds": mcpUniqueSorted(persona.defaultKitIds),
          "allowedSkillIds": mcpUniqueSorted(persona.allowedSkillIds),
          "forbiddenSkillIds": mcpUniqueSorted(persona.forbiddenSkillIds),
          "values": mcpUniqueSorted(persona.values),
          "nonGoals": mcpUniqueSorted(persona.nonGoals),
        ]
      )
    case .directive:
      guard let directive = registry.directivesById[id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .directive, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": directive.id,
          "title": directive.title,
          "goal": directive.goal,
          "version": directive.version,
        ],
        lists: [
          "requiresIntentTemplateIds": mcpUniqueSorted(directive.requiresIntentTemplateIds),
          "requiresSkillIds": mcpUniqueSorted(directive.requiresSkillIds),
          "acceptanceCriteria": mcpUniqueSorted(directive.acceptanceCriteria),
        ]
      )
    case .kit:
      guard let kit = registry.kitsById[id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .kit, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": kit.id,
          "name": kit.name,
          "summary": kit.summary,
          "version": kit.version,
        ],
        lists: [
          "essentialIds": mcpUniqueSorted(kit.essentialIds),
          "intentTemplateIds": mcpUniqueSorted(kit.intentTemplateIds ?? []),
          "skillIds": mcpUniqueSorted(kit.skillIds ?? []),
        ]
      )
    case .session:
      let session = try loadSession(id: id)
      return EntityComparableSnapshot(
        scalars: [
          "id": session.id,
          "personaId": session.personaId,
          "directiveId": session.directiveId,
        ],
        lists: [
          "kitOverrides": mcpUniqueSorted(session.kitOverrides ?? [])
        ]
      )
    case .intent:
      guard let intent = registry.intentTemplatesById[id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .intent, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": intent.id,
          "name": intent.name,
          "description": intent.description,
          "riskLevel": intent.risk.level,
          "requiresHumanReview": String(intent.risk.requiresHumanReview),
          "version": intent.version,
        ],
        lists: [
          "parameterConstraints": mcpUniqueSorted(
            (intent.parameterConstraints ?? []).map(mcpParameterConstraintSummary)
          ),
          "includesEssentialIds": mcpUniqueSorted(intent.includesEssentialIds),
          "requiresSkillIds": mcpUniqueSorted(intent.requiresSkillIds),
        ]
      )
    case .skill:
      guard let skill = registry.skillsById[id] else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .skill, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": skill.id,
          "name": skill.name,
          "description": skill.description,
          "riskLevel": skill.risk.level,
          "requiresHumanReview": String(skill.risk.requiresHumanReview),
          "version": skill.version,
        ],
        lists: [
          "providedBy": mcpUniqueSorted(skill.providedBy),
          "notes": mcpUniqueSorted(skill.notes),
        ]
      )
    case .essential:
      guard let fileURL = mcpResolveEssentialURL(id: id, scopes: scopes, fileManager: .default)
      else {
        throw MCPError.invalidParams(mcpMissingEntityMessage(entityType: .essential, id: id))
      }
      let content: String
      do {
        content = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw MCPError.internalError("Failed to read essential \(id).")
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": id,
          "resolvedPath": fileURL.path,
          "lineCount": String(mcpLineCount(content)),
          "byteCount": String(content.utf8.count),
        ],
        lists: [:]
      )
    }
  }
}
