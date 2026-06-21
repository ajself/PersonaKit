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

      for intentId in kit.intentTemplateIds ?? [] {
        if registry.intentTemplatesById[intentId] == nil {
          errors.append(
            ValidationError(
              entityType: .kit,
              entityId: kit.id,
              field: "intentTemplateIds",
              missingId: intentId,
              expectedPath: nil,
              message: "Missing intent template id \"\(intentId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

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

      for essentialId in kit.essentialIds {
        let expectedPath = PersonaKitEssentialResolver.expectedPath(for: essentialId)

        if !PersonaKitPathSafety.isSafePathSegment(essentialId) {
          errors.append(
            unsafePathSegmentError(
              entityType: .kit,
              entityId: kit.id,
              field: "essentialIds",
              value: essentialId,
              expectedPath: expectedPath,
              kind: "essential id"
            )
          )
        } else if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          if hasEscapingPath(
            scopes: scopes,
            baseRelativePath: "Packs/essentials",
            segment: essentialId,
            suffix: ".md",
            fileManager: fileManager
          ) {
            errors.append(
              unsafeResolvedPathError(
                entityType: .kit,
                entityId: kit.id,
                field: "essentialIds",
                value: essentialId,
                expectedPath: expectedPath,
                kind: "essential file"
              )
            )
            continue
          }

          errors.append(
            ValidationError(
              entityType: .kit,
              entityId: kit.id,
              field: "essentialIds",
              missingId: essentialId,
              expectedPath: expectedPath,
              message: "Missing essential file at \(expectedPath).",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for referenceId in kit.referenceIds ?? [] {
        if registry.referencesById[referenceId] == nil {
          errors.append(
            ValidationError(
              entityType: .kit,
              entityId: kit.id,
              field: "referenceIds",
              missingId: referenceId,
              expectedPath: nil,
              message: "Missing reference id \"\(referenceId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }
    }

    for directive in registry.directives {
      try ValidatorSupport.checkCancellation()

      for intentId in directive.requiresIntentTemplateIds {
        if registry.intentTemplatesById[intentId] == nil {
          errors.append(
            ValidationError(
              entityType: .directive,
              entityId: directive.id,
              field: "requiresIntentTemplateIds",
              missingId: intentId,
              expectedPath: nil,
              message: "Missing intent template id \"\(intentId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

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

      for referenceId in directive.referenceIds ?? [] {
        if registry.referencesById[referenceId] == nil {
          errors.append(
            ValidationError(
              entityType: .directive,
              entityId: directive.id,
              field: "referenceIds",
              missingId: referenceId,
              expectedPath: nil,
              message: "Missing reference id \"\(referenceId)\".",
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

    for intent in registry.intentTemplates {
      try ValidatorSupport.checkCancellation()

      let knownParameterNames = Set(intent.parameters.map(\.name))

      for essentialId in intent.includesEssentialIds {
        let expectedPath = PersonaKitEssentialResolver.expectedPath(for: essentialId)

        if !PersonaKitPathSafety.isSafePathSegment(essentialId) {
          errors.append(
            unsafePathSegmentError(
              entityType: .intent,
              entityId: intent.id,
              field: "includesEssentialIds",
              value: essentialId,
              expectedPath: expectedPath,
              kind: "essential id"
            )
          )
        } else if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          if hasEscapingPath(
            scopes: scopes,
            baseRelativePath: "Packs/essentials",
            segment: essentialId,
            suffix: ".md",
            fileManager: fileManager
          ) {
            errors.append(
              unsafeResolvedPathError(
                entityType: .intent,
                entityId: intent.id,
                field: "includesEssentialIds",
                value: essentialId,
                expectedPath: expectedPath,
                kind: "essential file"
              )
            )
            continue
          }

          errors.append(
            ValidationError(
              entityType: .intent,
              entityId: intent.id,
              field: "includesEssentialIds",
              missingId: essentialId,
              expectedPath: expectedPath,
              message: "Missing essential file at \(expectedPath).",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for skillId in intent.requiresSkillIds {
        if registry.skillsById[skillId] == nil {
          errors.append(
            ValidationError(
              entityType: .intent,
              entityId: intent.id,
              field: "requiresSkillIds",
              missingId: skillId,
              expectedPath: nil,
              message: "Missing skill id \"\(skillId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for referenceId in intent.referenceIds ?? [] {
        if registry.referencesById[referenceId] == nil {
          errors.append(
            ValidationError(
              entityType: .intent,
              entityId: intent.id,
              field: "referenceIds",
              missingId: referenceId,
              expectedPath: nil,
              message: "Missing reference id \"\(referenceId)\".",
              referencesUnresolvedID: true
            )
          )
        }
      }

      for constraint in intent.parameterConstraints ?? [] {
        switch constraint.kind {
        case "allDistinct":
          if constraint.parameterNames.count < 2 {
            errors.append(
              ValidationError(
                entityType: .intent,
                entityId: intent.id,
                field: "parameterConstraints",
                missingId: nil,
                expectedPath: nil,
                message: "Constraint kind \"allDistinct\" must reference at least two parameter names."
              )
            )
          }

          let uniqueParameterNames = Set(constraint.parameterNames)
          if uniqueParameterNames.count != constraint.parameterNames.count {
            errors.append(
              ValidationError(
                entityType: .intent,
                entityId: intent.id,
                field: "parameterConstraints",
                missingId: nil,
                expectedPath: nil,
                message: "Constraint kind \"allDistinct\" contains duplicate parameter names."
              )
            )
          }
        default:
          errors.append(
            ValidationError(
              entityType: .intent,
              entityId: intent.id,
              field: "parameterConstraints",
              missingId: nil,
              expectedPath: nil,
              message: "Unsupported parameter constraint kind \"\(constraint.kind)\"."
            )
          )
        }

        for parameterName in constraint.parameterNames {
          if !knownParameterNames.contains(parameterName) {
            errors.append(
              ValidationError(
                entityType: .intent,
                entityId: intent.id,
                field: "parameterConstraints",
                missingId: parameterName,
                expectedPath: nil,
                message: "Constraint references missing parameter name \"\(parameterName)\"."
              )
            )
          }
        }
      }
    }

    let decoder = JSONDecoder()
    for root in scopes.loadOrder {
      try ValidatorSupport.checkCancellation()

      let referencesURL = PersonaKitDirectory.referencesURL(root: root)
      var isDirectory: ObjCBool = false

      guard fileManager.fileExists(atPath: referencesURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }

      let files = try fileManager.contentsOfDirectory(
        at: referencesURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      let sortedFiles =
        files
        .filter { $0.lastPathComponent.hasSuffix(".reference.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      for fileURL in sortedFiles {
        try ValidatorSupport.checkCancellation()

        let data = try Data(contentsOf: fileURL)
        let reference = try decoder.decode(Reference.self, from: data)
        let expectedPath = ReferenceSupport.referenceBodyRelativePath(id: reference.id)

        if !PersonaKitPathSafety.isSafePathSegment(reference.id) {
          errors.append(
            unsafePathSegmentError(
              entityType: .reference,
              entityId: reference.id,
              field: "body",
              value: reference.id,
              expectedPath: expectedPath,
              kind: "reference id"
            )
          )
        } else if ReferenceSupport.resolveReferenceBodyURL(
          id: reference.id,
          root: root,
          fileManager: fileManager
        ) == nil {
          if hasEscapingPath(
            root: root,
            baseRelativePath: "Packs/references",
            segment: reference.id,
            suffix: ".md",
            fileManager: fileManager
          ) {
            errors.append(
              unsafeResolvedPathError(
                entityType: .reference,
                entityId: reference.id,
                field: "body",
                value: reference.id,
                expectedPath: expectedPath,
                kind: "reference body"
              )
            )
            continue
          }

          errors.append(
            ValidationError(
              entityType: .reference,
              entityId: reference.id,
              field: "body",
              missingId: reference.id,
              expectedPath: expectedPath,
              message: "Missing reference body at \(expectedPath)."
            )
          )
        }

        if reference.triggerRules.isEmpty {
          errors.append(
            ValidationError(
              entityType: .reference,
              entityId: reference.id,
              field: "triggerRules",
              missingId: nil,
              expectedPath: nil,
              message: "Reference must declare at least one trigger rule."
            )
          )
        }

        for (ruleIndex, triggerRule) in reference.triggerRules.enumerated() {
          let pathGlobs = (triggerRule.pathGlobs ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }
          let referenceTags = (triggerRule.referenceTags ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
          }

          if pathGlobs.allSatisfy(\.isEmpty) && referenceTags.allSatisfy(\.isEmpty) {
            errors.append(
              ValidationError(
                entityType: .reference,
                entityId: reference.id,
                field: "triggerRules[\(ruleIndex)]",
                missingId: nil,
                expectedPath: nil,
                message: "Trigger rule must declare at least one non-empty pathGlobs or referenceTags value."
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
  scopes: ScopeSet,
  baseRelativePath: String,
  segment: String,
  suffix: String,
  fileManager: FileManager
) -> Bool {
  scopes.resolutionOrder.contains { root in
    hasEscapingPath(
      root: root,
      baseRelativePath: baseRelativePath,
      segment: segment,
      suffix: suffix,
      fileManager: fileManager
    )
  }
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
