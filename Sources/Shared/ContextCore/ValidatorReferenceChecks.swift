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
              message: "Missing kit id \"\(kitId)\"."
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
              message: "Missing skill id \"\(skillId)\"."
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
              message: "Missing skill id \"\(skillId)\"."
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
              message: "Missing intent template id \"\(intentId)\"."
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
              message: "Missing skill id \"\(skillId)\"."
            )
          )
        }
      }

      for essentialId in kit.essentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"
        if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          errors.append(
            ValidationError(
              entityType: .kit,
              entityId: kit.id,
              field: "essentialIds",
              missingId: essentialId,
              expectedPath: expectedPath,
              message: "Missing essential file at \(expectedPath)."
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
              message: "Missing reference id \"\(referenceId)\"."
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
              message: "Missing intent template id \"\(intentId)\"."
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
              message: "Missing skill id \"\(skillId)\"."
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
              message: "Missing reference id \"\(referenceId)\"."
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
      contentsOf: WorkstreamDocsBuilder.consistencyErrors(
        directives: registry.directives
      )
    )

    for intent in registry.intentTemplates {
      try ValidatorSupport.checkCancellation()

      let knownParameterNames = Set(intent.parameters.map(\.name))

      for essentialId in intent.includesEssentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"
        if resolveReferencedEssential(essentialId, scopes: scopes, fileManager: fileManager) == nil {
          errors.append(
            ValidationError(
              entityType: .intent,
              entityId: intent.id,
              field: "includesEssentialIds",
              missingId: essentialId,
              expectedPath: expectedPath,
              message: "Missing essential file at \(expectedPath)."
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
              message: "Missing skill id \"\(skillId)\"."
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
              message: "Missing reference id \"\(referenceId)\"."
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
      let sortedFiles = files
        .filter { $0.lastPathComponent.hasSuffix(".reference.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      for fileURL in sortedFiles {
        try ValidatorSupport.checkCancellation()

        let data = try Data(contentsOf: fileURL)
        let reference = try decoder.decode(Reference.self, from: data)
        let expectedPath = ReferenceSupport.referenceBodyRelativePath(id: reference.id)
        let bodyURL = root.appendingPathComponent(expectedPath)

        if !fileManager.fileExists(atPath: bodyURL.path) {
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

    let sessionIds = try SessionFileLoader.discoveredSessionIDs(
      scopes: scopes,
      fileManager: fileManager
    )

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
