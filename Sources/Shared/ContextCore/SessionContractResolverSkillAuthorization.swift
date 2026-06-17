import Foundation

enum SessionContractSkillAuthorizationEvaluator {
  static func evaluate(
    persona: Persona,
    requiredSkillReferences: [SessionContractRequiredSkillReference],
    declaredSkillIds: Set<String>,
    requestedSkillIds: [String],
    skillCapabilitiesById: [String: Set<String>] = [:]
  ) -> (contract: ResolvedSkillAuthorization, errors: [ResolverError]) {
    let allowedSkillIds = sortedUniqueValues(persona.allowedSkillIds)
    let forbiddenSkillIds = sortedUniqueValues(persona.forbiddenSkillIds)
    let conflictingPersonaSkillIds = allowedSkillIds.filter { forbiddenSkillIds.contains($0) }
    let idAuthorizedSkillIds = allowedSkillIds.filter { !forbiddenSkillIds.contains($0) }

    // Capability-level forbids: an id-authorized skill whose declared capability the
    // persona forbids via forbiddenCapabilities. Surfaces the read-only-stance contradiction.
    let forbiddenCapabilities = Set(persona.forbiddenCapabilities ?? [])
    let capabilityConflicts: [(skillId: String, capability: String)] =
      forbiddenCapabilities.isEmpty
      ? []
      : idAuthorizedSkillIds.flatMap { skillId in
        (skillCapabilitiesById[skillId] ?? []).intersection(forbiddenCapabilities).sorted()
          .map { (skillId, $0) }
      }
    let capabilityForbiddenSkillIds = sortedUniqueValues(capabilityConflicts.map(\.skillId))
    let authorizedSkillIds = idAuthorizedSkillIds.filter { !capabilityForbiddenSkillIds.contains($0) }
    let requiredSkillIds = sortedUniqueValues(requiredSkillReferences.map(\.skillId))

    let unauthorizedRequiredReferences = requiredSkillReferences.filter { reference in
      !authorizedSkillIds.contains(reference.skillId)
    }
    let unauthorizedRequiredSkillIds = sortedUniqueValues(unauthorizedRequiredReferences.map(\.skillId))
    let normalizedRequestedSkillIds = sortedUniqueValues(requestedSkillIds)
    let undeclaredRequestedSkillIds = normalizedRequestedSkillIds.filter {
      !declaredSkillIds.contains($0)
    }
    let unauthorizedRequestedSkillIds = normalizedRequestedSkillIds.filter { skillId in
      declaredSkillIds.contains(skillId) && !authorizedSkillIds.contains(skillId)
    }

    var failureReasons: [String] = conflictingPersonaSkillIds.map { skillId in
      "persona \(persona.id) lists \(skillId) in both allowedSkillIds and forbiddenSkillIds"
    }

    failureReasons.append(
      contentsOf: capabilityConflicts.map { conflict in
        "persona \(persona.id) authorizes skill \(conflict.skillId) with capability \(conflict.capability) forbidden by forbiddenCapabilities"
      }
    )

    failureReasons.append(
      contentsOf: unauthorizedRequiredReferences.map { reference in
        "\(reference.sourceType.rawValue) \(reference.sourceId) requires unauthorized skill \(reference.skillId)"
      }
    )

    failureReasons.append(
      contentsOf: undeclaredRequestedSkillIds.map { skillId in
        "requested skill \(skillId) is not declared in PersonaKit"
      }
    )

    failureReasons.append(
      contentsOf: unauthorizedRequestedSkillIds.map { skillId in
        "requested skill \(skillId) is declared in PersonaKit but not authorized by persona \(persona.id)"
      }
    )

    let authorizationErrors =
      conflictingPersonaSkillIds.map { skillId in
        ResolverError.conflictingPersonaSkillId(
          sourceId: persona.id,
          field: "allowedSkillIds",
          missingId: skillId
        )
      }
      + capabilityConflicts.map { conflict in
        ResolverError.conflictingPersonaSkillCapability(
          sourceId: persona.id,
          field: "forbiddenCapabilities",
          skillId: conflict.skillId,
          capability: conflict.capability
        )
      }
      + unauthorizedRequiredReferences.map { reference in
        ResolverError.unauthorizedSkillId(
          sourceType: reference.sourceType,
          sourceId: reference.sourceId,
          field: reference.field,
          missingId: reference.skillId
        )
      }

    let contract = ResolvedSkillAuthorization(
      allowedSkillIds: allowedSkillIds,
      forbiddenSkillIds: forbiddenSkillIds,
      conflictingPersonaSkillIds: conflictingPersonaSkillIds,
      authorizedSkillIds: authorizedSkillIds,
      requiredSkillIds: requiredSkillIds,
      unauthorizedRequiredSkillIds: unauthorizedRequiredSkillIds,
      requestedSkillIds: normalizedRequestedSkillIds,
      undeclaredRequestedSkillIds: undeclaredRequestedSkillIds,
      unauthorizedRequestedSkillIds: unauthorizedRequestedSkillIds,
      isAuthorized:
        conflictingPersonaSkillIds.isEmpty
        && capabilityForbiddenSkillIds.isEmpty
        && unauthorizedRequiredSkillIds.isEmpty
        && undeclaredRequestedSkillIds.isEmpty
        && unauthorizedRequestedSkillIds.isEmpty,
      failureReasons: failureReasons.sorted()
    )

    return (contract, authorizationErrors)
  }
}

private func sortedUniqueValues(_ values: [String]) -> [String] {
  Set(values).sorted()
}
