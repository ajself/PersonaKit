import Foundation

enum ValidatorReferenceChecker {
  static func validate(
    registry: Registry,
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> [ValidationError] {
    var errors: [ValidationError] = []

    for persona in registry.personas {
      try ValidatorSupport.checkCancellation()

      for kitId in persona.defaultKitIds {
        if registry.kitsById[kitId] == nil {
          errors.append(
            ValidationError(
              entityType: .persona,
              entityId: persona.id,
              field: "defaultKitIds",
              missingId: kitId,
              expectedPath: nil,
              message: "Missing kit id \"\(kitId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for skillId in persona.allowedSkillIds {
        if registry.skillsById[skillId] == nil {
          errors.append(
            ValidationError(
              entityType: .persona,
              entityId: persona.id,
              field: "allowedSkillIds",
              missingId: skillId,
              expectedPath: nil,
              message: "Missing skill id \"\(skillId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for skillId in persona.forbiddenSkillIds {
        if registry.skillsById[skillId] == nil {
          errors.append(
            ValidationError(
              entityType: .persona,
              entityId: persona.id,
              field: "forbiddenSkillIds",
              missingId: skillId,
              expectedPath: nil,
              message: "Missing skill id \"\(skillId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for conflictingSkillId in Set(persona.allowedSkillIds).intersection(Set(persona.forbiddenSkillIds))
        .sorted()
      {
        errors.append(
          ValidationError(
            entityType: .persona,
            entityId: persona.id,
            field: "allowedSkillIds",
            missingId: conflictingSkillId,
            expectedPath: nil,
            message:
              "Skill id \"\(conflictingSkillId)\" cannot appear in both allowedSkillIds and forbiddenSkillIds."
          )
        )
      }
    }

    for kit in registry.kits {
      try ValidatorSupport.checkCancellation()

      for skillId in kit.skillIds ?? [] {
        if registry.skillsById[skillId] == nil {
          errors.append(
            ValidationError(
              entityType: .kit,
              entityId: kit.id,
              field: "skillIds",
              missingId: skillId,
              expectedPath: nil,
              message: "Missing skill id \"\(skillId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }
    }

    for directive in registry.directives {
      try ValidatorSupport.checkCancellation()

      for skillId in directive.requiresSkillIds {
        if registry.skillsById[skillId] == nil {
          errors.append(
            ValidationError(
              entityType: .directive,
              entityId: directive.id,
              field: "requiresSkillIds",
              missingId: skillId,
              expectedPath: nil,
              message: "Missing skill id \"\(skillId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      if let workstream = directive.workstream {
        errors.append(
          contentsOf: ValidatorWorkstreamValidator.validate(
            workstream,
            directiveId: directive.id,
            scopes: scopes,
            fileManager: fileManager
          )
        )
      }
    }

    errors.append(
      contentsOf: ValidatorWorkstreamValidator.consistencyErrors(
        directives: registry.directives
      )
    )

    let decoder = JSONDecoder()
    for root in scopes.loadOrder {
      try ValidatorSupport.checkCancellation()

      let skillsURL = PersonaKitDirectory.skillsURL(root: root)
      var isDirectory: ObjCBool = false

      guard fileManager.fileExists(atPath: skillsURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }

      let files = try fileManager.contentsOfDirectory(
        at: skillsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      let sortedFiles =
        files
        .filter { $0.lastPathComponent.hasSuffix(".skill.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      for fileURL in sortedFiles {
        try ValidatorSupport.checkCancellation()

        let data = try Data(contentsOf: fileURL)
        let skill = try decoder.decode(Skill.self, from: data)

        // Body and trigger validation applies only to grounding skills (former
        // references): a tool-awareness skill carries neither and needs neither.
        guard skill.isGrounding else {
          continue
        }

        let triggerRules = skill.triggerRules ?? []
        let expectedPath = GroundingSkillSupport.groundingSkillBodyRelativePath(id: skill.id)

        if !PersonaKitPathSafety.isSafePathSegment(skill.id) {
          errors.append(
            unsafePathSegmentError(
              entityType: .skill,
              entityId: skill.id,
              field: "body",
              value: skill.id,
              expectedPath: expectedPath,
              kind: "skill id"
            )
          )
        } else if GroundingSkillSupport.resolveGroundingSkillBodyURL(
          id: skill.id,
          root: root,
          fileManager: fileManager
        ) == nil {
          if hasEscapingPath(
            root: root,
            baseRelativePath: "Packs/skills",
            segment: skill.id,
            suffix: ".md",
            fileManager: fileManager
          ) {
            errors.append(
              unsafeResolvedPathError(
                entityType: .skill,
                entityId: skill.id,
                field: "body",
                value: skill.id,
                expectedPath: expectedPath,
                kind: "grounding-skill body"
              )
            )
            continue
          }

          errors.append(
            ValidationError(
              entityType: .skill,
              entityId: skill.id,
              field: "body",
              missingId: skill.id,
              expectedPath: expectedPath,
              message: "Missing grounding-skill body at \(expectedPath)."
            )
          )
        }

        for (ruleIndex, triggerRule) in triggerRules.enumerated() {
          let pathGlobs = (triggerRule.pathGlobs ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }
          let skillTags = (triggerRule.skillTags ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }

          // A rule with no declared path/tag arrays is an intentional always-on
          // rule and is valid. Only flag a rule that declares arrays whose every
          // entry is blank, which is a useless (mistaken) condition.
          let declaresConditions = !pathGlobs.isEmpty || !skillTags.isEmpty
          let hasUsableCondition =
            pathGlobs.contains { !$0.isEmpty } || skillTags.contains { !$0.isEmpty }

          if declaresConditions && !hasUsableCondition {
            errors.append(
              ValidationError(
                entityType: .skill,
                entityId: skill.id,
                field: "triggerRules[\(ruleIndex)]",
                missingId: nil,
                expectedPath: nil,
                message: "Trigger rule declares only blank pathGlobs or skillTags values; leave both unset for an always-on rule or provide a non-blank condition."
              )
            )
          }
        }
      }
    }

    let sessionIds: [String]

    do {
      sessionIds = try SessionFileLoader.discoveredSessionIDs(
        scopes: scopes,
        fileManager: fileManager
      )
    } catch let error as SessionFileError {
      errors.append(ValidatorSupport.sessionDiscoveryValidationError(for: error))
      return errors
    }

    for sessionId in sessionIds {
      try ValidatorSupport.checkCancellation()

      let session: SessionFile

      do {
        session = try SessionFileLoader.load(
          scopes: scopes,
          sessionId: sessionId,
          fileManager: fileManager
        )
      } catch let error as SessionFileError {
        errors.append(ValidatorSupport.validationError(for: error, sessionId: sessionId))
        continue
      }

      do {
        let contract = try SessionContractResolver.resolve(
          definition: SessionContractDefinition(
            personaId: session.personaId,
            directiveId: session.directiveId,
            kitOverrides: session.kitOverrides
          ),
          sessionId: session.id,
          registry: registry,
          scopes: scopes,
          fileManager: fileManager
        )

        errors.append(
          contentsOf: contract.authorizationErrors.map {
            ValidatorSupport.validationError(for: $0, sessionId: session.id)
          }
        )
      } catch let error as ResolverResolutionError {
        errors.append(
          contentsOf: error.errors.map {
            ValidatorSupport.validationError(for: $0, sessionId: session.id)
          }
        )
      }
    }

    return errors
  }
}

private func unsafePathSegmentError(
  entityType: ValidationEntityType,
  entityId: String?,
  field: String,
  value: String,
  expectedPath: String,
  kind: String
) -> ValidationError {
  ValidationError(
    entityType: entityType,
    entityId: entityId,
    field: field,
    missingId: value,
    expectedPath: expectedPath,
    message: "Unsafe \(kind) path segment \"\(value)\"."
  )
}

private func unsafeResolvedPathError(
  entityType: ValidationEntityType,
  entityId: String?,
  field: String,
  value: String,
  expectedPath: String,
  kind: String
) -> ValidationError {
  ValidationError(
    entityType: entityType,
    entityId: entityId,
    field: field,
    missingId: value,
    expectedPath: expectedPath,
    message: "Unsafe \(kind) path for id \"\(value)\"."
  )
}

private func hasEscapingPath(
  root: URL,
  baseRelativePath: String,
  segment: String,
  suffix: String,
  fileManager: FileManager
) -> Bool {
  guard
    let uncheckedURL = PersonaKitPathSafety.fileURL(
      root: root,
      baseRelativePath: baseRelativePath,
      segment: segment,
      suffix: suffix
    )
  else {
    return false
  }

  guard fileManager.fileExists(atPath: uncheckedURL.path) else {
    return false
  }

  return PersonaKitPathSafety.containedFileURL(
    root: root,
    baseRelativePath: baseRelativePath,
    segment: segment,
    suffix: suffix
  ) == nil
}
