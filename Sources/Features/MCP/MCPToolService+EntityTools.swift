import ContextCore
import Foundation
import MCP

extension MCPToolService {
  func explainEntityTool(input: MCPEntityArguments) throws -> String {
    let registry = try loadRegistry()

    switch input.entityType {
    case .persona:
      guard let persona = registry.personasById[input.id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .persona, id: input.id)
        )
      }
      return try MCPInternalSupport.encodeToolJSON(
        MCPToolPayloads.ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: MCPToolPayloads.PersonaExplainData(
            name: persona.name,
            summary: persona.summary,
            defaultKitIds: MCPInternalSupport.uniqueSorted(persona.defaultKitIds),
            allowedSkillIds: MCPInternalSupport.uniqueSorted(persona.allowedSkillIds),
            forbiddenSkillIds: MCPInternalSupport.uniqueSorted(persona.forbiddenSkillIds),
            responsibilitiesCount: persona.responsibilities.count,
            valuesCount: persona.values.count,
            nonGoalsCount: persona.nonGoals.count
          )
        )
      )
    case .directive:
      guard let directive = registry.directivesById[input.id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .directive, id: input.id)
        )
      }
      let reviewStepCount = directive.steps.filter { $0.requiresReview == true }.count
      return try MCPInternalSupport.encodeToolJSON(
        MCPToolPayloads.ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: MCPToolPayloads.DirectiveExplainData(
            title: directive.title,
            goal: directive.goal,
            parameters: directive.parameters.map(\.name).sorted(),
            requiredSkillIds: MCPInternalSupport.uniqueSorted(directive.requiresSkillIds),
            stepsCount: directive.steps.count,
            reviewStepCount: reviewStepCount,
            riskLevel: directive.risk?.level,
            requiresHumanReview: directive.risk?.requiresHumanReview,
            workstream: directive.workstream.map(MCPInternalSupport.directiveExplainWorkstreamData)
          )
        )
      )
    case .kit:
      guard let kit = registry.kitsById[input.id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .kit, id: input.id)
        )
      }
      return try MCPInternalSupport.encodeToolJSON(
        MCPToolPayloads.ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: MCPToolPayloads.KitExplainData(
            name: kit.name,
            summary: kit.summary,
            skillIds: MCPInternalSupport.uniqueSorted(kit.skillIds ?? [])
          )
        )
      )
    case .skill:
      guard let skill = registry.skillsById[input.id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .skill, id: input.id)
        )
      }
      return try MCPInternalSupport.encodeToolJSON(
        MCPToolPayloads.ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: MCPToolPayloads.SkillExplainData(
            name: skill.name,
            description: skill.description,
            providedBy: MCPInternalSupport.uniqueSorted(skill.providedBy ?? []),
            capabilities: MCPInternalSupport.uniqueSorted(skill.capabilities ?? []),
            triggerSummaries: (skill.triggerRules ?? []).map(GroundingSkillSupport.triggerSummary(for:)),
            riskLevel: skill.risk?.level ?? "",
            requiresHumanReview: skill.risk?.requiresHumanReview ?? false,
            notesCount: (skill.notes ?? []).count
          )
        )
      )
    case .session:
      let session = try loadSession(id: input.id)
      let personaExists = registry.personasById[session.personaId] != nil
      let directiveExists = registry.directivesById[session.directiveId] != nil
      let missingKits = MCPInternalSupport.uniqueSorted(
        (session.kitOverrides ?? []).filter { registry.kitsById[$0] == nil }
      )
      return try MCPInternalSupport.encodeToolJSON(
        MCPToolPayloads.ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: MCPToolPayloads.SessionExplainData(
            personaId: session.personaId,
            directiveId: session.directiveId,
            kitOverrides: MCPInternalSupport.uniqueSorted(session.kitOverrides ?? []),
            personaExists: personaExists,
            directiveExists: directiveExists,
            missingKitOverrides: missingKits
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
    let scalarDifferences = scalarKeys.compactMap { key -> MCPToolPayloads.CompareScalarDifference? in
      let leftValue = left.scalars[key] ?? ""
      let rightValue = right.scalars[key] ?? ""
      guard leftValue != rightValue else {
        return nil
      }
      return MCPToolPayloads.CompareScalarDifference(field: key, left: leftValue, right: rightValue)
    }

    let listKeys = Set(left.lists.keys).union(right.lists.keys).sorted()
    let listMatches = listKeys.filter { left.lists[$0] == right.lists[$0] }
    let listDifferences = listKeys.compactMap { key -> MCPToolPayloads.CompareListDifference? in
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

      return MCPToolPayloads.CompareListDifference(
        field: key,
        shared: shared,
        onlyLeft: onlyLeft,
        onlyRight: onlyRight
      )
    }

    return try MCPInternalSupport.encodeToolJSON(
      MCPToolPayloads.ComparePayload(
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
    let sessions = try MCPInternalSupport.listSessions(scopes: scopes, fileManager: .default)

    guard !sessions.isEmpty else {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          "No session files found in active scopes.",
          hint: "Create at least one Sessions/*.session.json file in the active PersonaKit scope."
        )
      )
    }

    let result = SessionRecommendationSupport.recommend(
      goal: input.goal,
      sessions: sessions,
      registry: registry
    )

    if !result.invalidSessions.isEmpty {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          SessionRecommendationSupport.formatInvalidSessions(result.invalidSessions),
          hint: "Fix or remove invalid Sessions/*.session.json files in the active PersonaKit scope, then retry."
        )
      )
    }

    let strongRecommendations = result.recommendations.filter { $0.score > 0 }
    let selected = Array(strongRecommendations.prefix(input.limit)).map { recommendation in
      MCPToolPayloads.SessionRecommendation(
        sessionId: recommendation.sessionId,
        personaId: recommendation.personaId,
        directiveId: recommendation.directiveId,
        kitOverrides: recommendation.kitOverrides,
        score: recommendation.score,
        matchedGoalTerms: recommendation.matchedGoalTerms,
        termMatches: MCPToolPayloads.SessionRecommendationTermMatches(
          persona: recommendation.termMatches.persona,
          directive: recommendation.termMatches.directive,
          session: recommendation.termMatches.session
        )
      )
    }

    return try MCPInternalSupport.encodeToolJSON(
      MCPToolPayloads.SessionRecommendationPayload(
        goal: input.goal,
        goalTerms: result.goalTerms,
        consideredSessions: result.consideredSessionIds,
        policy: MCPToolPayloads.SessionRecommendationPolicy(),
        recommendations: selected
      )
    )
  }

  func comparableSnapshot(
    type: MCPEntityType,
    id: String,
    registry: Registry
  ) throws -> MCPToolPayloads.EntityComparableSnapshot {
    switch type {
    case .persona:
      guard let persona = registry.personasById[id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .persona, id: id)
        )
      }
      return MCPToolPayloads.EntityComparableSnapshot(
        scalars: [
          "id": persona.id,
          "name": persona.name,
          "summary": persona.summary,
          "version": persona.version,
        ],
        lists: [
          "defaultKitIds": MCPInternalSupport.uniqueSorted(persona.defaultKitIds),
          "allowedSkillIds": MCPInternalSupport.uniqueSorted(persona.allowedSkillIds),
          "forbiddenSkillIds": MCPInternalSupport.uniqueSorted(persona.forbiddenSkillIds),
          "values": MCPInternalSupport.uniqueSorted(persona.values),
          "nonGoals": MCPInternalSupport.uniqueSorted(persona.nonGoals),
        ]
      )
    case .directive:
      guard let directive = registry.directivesById[id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .directive, id: id)
        )
      }
      var directiveScalars: [String: String] = [
        "id": directive.id,
        "title": directive.title,
        "goal": directive.goal,
        "version": directive.version,
      ]
      if let risk = directive.risk {
        directiveScalars["riskLevel"] = risk.level
        directiveScalars["requiresHumanReview"] = String(risk.requiresHumanReview)
      }
      return MCPToolPayloads.EntityComparableSnapshot(
        scalars: directiveScalars,
        lists: [
          "parameters": MCPInternalSupport.uniqueSorted(directive.parameters.map(\.name)),
          "requiresSkillIds": MCPInternalSupport.uniqueSorted(directive.requiresSkillIds),
          "acceptanceCriteria": MCPInternalSupport.uniqueSorted(directive.acceptanceCriteria),
        ]
      )
    case .kit:
      guard let kit = registry.kitsById[id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .kit, id: id)
        )
      }
      return MCPToolPayloads.EntityComparableSnapshot(
        scalars: [
          "id": kit.id,
          "name": kit.name,
          "summary": kit.summary,
          "version": kit.version,
        ],
        lists: [
          "skillIds": MCPInternalSupport.uniqueSorted(kit.skillIds ?? []),
        ]
      )
    case .session:
      let session = try loadSession(id: id)
      return MCPToolPayloads.EntityComparableSnapshot(
        scalars: [
          "id": session.id,
          "personaId": session.personaId,
          "directiveId": session.directiveId,
        ],
        lists: [
          "kitOverrides": MCPInternalSupport.uniqueSorted(session.kitOverrides ?? [])
        ]
      )
    case .skill:
      guard let skill = registry.skillsById[id] else {
        throw MCPError.invalidParams(
          MCPInternalSupport.missingEntityMessage(entityType: .skill, id: id)
        )
      }
      var skillScalars: [String: String] = [
        "id": skill.id,
        "name": skill.name,
        "description": skill.description,
        "version": skill.version,
      ]
      if let risk = skill.risk {
        skillScalars["riskLevel"] = risk.level
        skillScalars["requiresHumanReview"] = String(risk.requiresHumanReview)
      }
      return MCPToolPayloads.EntityComparableSnapshot(
        scalars: skillScalars,
        lists: [
          "providedBy": MCPInternalSupport.uniqueSorted(skill.providedBy ?? []),
          "capabilities": MCPInternalSupport.uniqueSorted(skill.capabilities ?? []),
          "triggerSummaries": (skill.triggerRules ?? []).map(GroundingSkillSupport.triggerSummary(for:)),
          "notes": MCPInternalSupport.uniqueSorted(skill.notes ?? []),
        ]
      )
    }
  }
}
