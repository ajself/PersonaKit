import Foundation

/// Performs schema and cross-reference validation for PersonaKit pack data.
public struct Validator {
  /// Validates a single root as project scope only.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory containing `Packs/`.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic validation result.
  public static func validate(root: URL, fileManager: FileManager = .default) throws -> ValidationResult {
    try validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      fileManager: fileManager
    )
  }

  /// Validates schema and references across project/global scopes.
  ///
  /// - Parameters:
  ///   - scopes: Scope set used for loading, schema checks, and path resolution.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic validation result.
  public static func validate(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws
    -> ValidationResult
  {
    try checkCancellation()

    let schemaErrors = SchemaValidator.validate(scopes: scopes, fileManager: fileManager)
    var errors: [ValidationError] = schemaErrors.map { error in
      let message: String
      if let location = error.instanceLocation {
        message = "Schema \(error.schemaName): \(error.message) location=\(location)"
      } else {
        message = "Schema \(error.schemaName): \(error.message)"
      }
      return ValidationError(
        entityType: map(schemaPath: error.relativePath),
        entityId: nil,
        field: "schema",
        missingId: nil,
        expectedPath: error.relativePath,
        message: message
      )
    }

    let registry: Registry
    do {
      registry = try Registry.load(scopes: scopes, fileManager: fileManager)
    } catch let error as RegistryLoadError {
      errors.append(
        contentsOf: error.errors.map { registryError in
          ValidationError(
            entityType: map(entityType: registryError.entityType),
            entityId: registryError.id,
            field: registryError.id == nil ? "file" : "id",
            missingId: nil,
            expectedPath: registryError.relativePath,
            message: registryError.message
          )
        }
      )
      return ValidationResult(counts: .zero, errors: errors)
    }

    let essentialIds = listEssentialIds(scopes: scopes, fileManager: fileManager)
    if !schemaErrors.isEmpty {
      // Skip reference checks when schema errors exist to avoid noisy cascades.
      let counts = ValidationCounts(
        personas: registry.personasById.count,
        kits: registry.kitsById.count,
        directives: registry.directivesById.count,
        intents: registry.intentTemplatesById.count,
        skills: registry.skillsById.count,
        essentials: essentialIds.count
      )
      return ValidationResult(counts: counts, errors: errors)
    }

    for persona in registry.personas {
      try checkCancellation()

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
      try checkCancellation()

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
    }

    for directive in registry.directives {
      try checkCancellation()

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

      if let workstream = directive.workstream {
        errors.append(
          contentsOf: validateWorkstream(
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
      try checkCancellation()

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

    let sessionIds = try SessionFileLoader.discoveredSessionIDs(
      scopes: scopes,
      fileManager: fileManager
    )

    for sessionId in sessionIds {
      try checkCancellation()

      let session: SessionFile

      do {
        session = try SessionFileLoader.load(
          scopes: scopes,
          sessionId: sessionId,
          fileManager: fileManager
        )
      } catch let error as SessionFileError {
        errors.append(validationError(for: error, sessionId: sessionId))
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
            validationError(for: $0, sessionId: session.id)
          }
        )
      } catch let error as ResolverResolutionError {
        errors.append(
          contentsOf: error.errors.map {
            validationError(for: $0, sessionId: session.id)
          }
        )
      }
    }

    let counts = ValidationCounts(
      personas: registry.personasById.count,
      kits: registry.kitsById.count,
      directives: registry.directivesById.count,
      intents: registry.intentTemplatesById.count,
      skills: registry.skillsById.count,
      essentials: essentialIds.count
    )

    return ValidationResult(counts: counts, errors: errors)
  }

  /// Maps registry error entity types to validation reporting categories.
  private static func map(entityType: RegistryEntityType) -> ValidationEntityType {
    switch entityType {
    case .persona:
      return .persona
    case .kit:
      return .kit
    case .directive:
      return .directive
    case .intentTemplate:
      return .intent
    case .skill:
      return .skill
    case .packsRoot:
      return .essentials
    }
  }

  /// Infers validation entity category from a schema file path.
  private static func map(schemaPath: String) -> ValidationEntityType {
    if schemaPath.contains("/personas/") || schemaPath.hasSuffix(".persona.json") {
      return .persona
    }
    if schemaPath.contains("/kits/") || schemaPath.hasSuffix(".kit.json") {
      return .kit
    }
    if schemaPath.contains("/directives/") || schemaPath.hasSuffix(".directive.json") {
      return .directive
    }
    if schemaPath.contains("/intents/") || schemaPath.hasSuffix(".intent.json") {
      return .intent
    }
    if schemaPath.contains("/skills/") || schemaPath.hasSuffix(".skill.json") {
      return .skill
    }
    return .essentials
  }

  private static func checkCancellation() throws {
    if Task.isCancelled {
      throw CancellationError()
    }
  }
}

private func validationError(
  for error: ResolverError,
  sessionId: String
) -> ValidationError {
  let expectedPath: String?

  if case .missingEssentialFile(_, _, _, _, let path) = error {
    expectedPath = path
  } else {
    expectedPath = nil
  }

  return ValidationError(
    entityType: .session,
    entityId: sessionId,
    field: error.field,
    missingId: error.missingId,
    expectedPath: expectedPath,
    message: error.message
  )
}

private func validationError(
  for error: SessionFileError,
  sessionId: String
) -> ValidationError {
  let field: String
  let missingId: String?
  let expectedPath: String?

  switch error {
  case .notFound(_, let path):
    field = "sessionFile"
    missingId = sessionId
    expectedPath = path
  case .decodeFailed:
    field = "sessionFile"
    missingId = sessionId
    expectedPath = "Sessions/\(sessionId).session.json"
  case .idMismatch:
    field = "id"
    missingId = sessionId
    expectedPath = "Sessions/\(sessionId).session.json"
  case .invalidSessionId, .invalidSessionPath:
    field = "sessionFile"
    missingId = sessionId
    expectedPath = "Sessions/\(sessionId).session.json"
  }

  return ValidationError(
    entityType: .session,
    entityId: sessionId,
    field: field,
    missingId: missingId,
    expectedPath: expectedPath,
    message: error.localizedDescription
  )
}

private func validateWorkstream(
  _ workstream: Directive.Workstream,
  directiveId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> [ValidationError] {
  var errors: [ValidationError] = []

  let phases = workstream.nodes.map(\.phase)
  let sessionIds = workstream.nodes.map(\.sessionId)
  let edgeTriplets = workstream.edges.map { "\($0.fromSessionId)|\($0.toSessionId)|\($0.kind)" }

  if let duplicatePhase = duplicateValue(in: phases) {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.nodes.phase",
        missingId: duplicatePhase,
        expectedPath: nil,
        message: "Duplicate workstream node phase \"\(duplicatePhase)\"."
      )
    )
  }

  if let duplicateSessionId = duplicateValue(in: sessionIds) {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.nodes.sessionId",
        missingId: duplicateSessionId,
        expectedPath: nil,
        message: "Duplicate workstream node session id \"\(duplicateSessionId)\"."
      )
    )
  }

  if let duplicateEdge = duplicateValue(in: edgeTriplets) {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.edges",
        missingId: duplicateEdge,
        expectedPath: nil,
        message: "Duplicate workstream edge \"\(duplicateEdge)\"."
      )
    )
  }

  let phaseMatches = workstream.nodes.filter { $0.phase == workstream.phase }
  if phaseMatches.count != 1 {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.phase",
        missingId: workstream.phase,
        expectedPath: nil,
        message: "Workstream phase \"\(workstream.phase)\" must match exactly one node phase."
      )
    )
  }

  let declaredSessionIds = Set(sessionIds)

  if !declaredSessionIds.contains(workstream.entrySessionId) {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.entrySessionId",
        missingId: workstream.entrySessionId,
        expectedPath: "Sessions/\(workstream.entrySessionId).session.json",
        message: "Workstream entry session id \"\(workstream.entrySessionId)\" must be declared in workstream nodes."
      )
    )
  }

  if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId,
    !declaredSessionIds.contains(requiredCloseoutSessionId)
  {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.requiredCloseoutSessionId",
        missingId: requiredCloseoutSessionId,
        expectedPath: "Sessions/\(requiredCloseoutSessionId).session.json",
        message: "Required closeout session id \"\(requiredCloseoutSessionId)\" must be declared in workstream nodes."
      )
    )
  }

  for sessionId in declaredSessionIds.sorted() {
    do {
      _ = try SessionFileLoader.load(
        scopes: scopes,
        sessionId: sessionId,
        fileManager: fileManager
      )
    } catch let error as SessionFileError {
      let message: String

      switch error {
      case .notFound:
        message = "Missing session file for workstream node id \"\(sessionId)\"."
      case .idMismatch:
        message = "Workstream node session id \"\(sessionId)\" failed to resolve: \(error.localizedDescription)"
      case .decodeFailed:
        message = "Workstream node session id \"\(sessionId)\" failed to decode."
      case .invalidSessionId, .invalidSessionPath:
        message = "Workstream node session id \"\(sessionId)\" failed to resolve."
      }

      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.nodes.sessionId",
          missingId: sessionId,
          expectedPath: "Sessions/\(sessionId).session.json",
          message: message
        )
      )
    } catch {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.nodes.sessionId",
          missingId: sessionId,
          expectedPath: "Sessions/\(sessionId).session.json",
          message: "Workstream node session id \"\(sessionId)\" failed to resolve."
        )
      )
    }
  }

  for edge in workstream.edges {
    if !declaredSessionIds.contains(edge.fromSessionId) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.edges.fromSessionId",
          missingId: edge.fromSessionId,
          expectedPath: "Sessions/\(edge.fromSessionId).session.json",
          message: "Workstream edge source session id \"\(edge.fromSessionId)\" must be declared in workstream nodes."
        )
      )
    }

    if !declaredSessionIds.contains(edge.toSessionId) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.edges.toSessionId",
          missingId: edge.toSessionId,
          expectedPath: "Sessions/\(edge.toSessionId).session.json",
          message: "Workstream edge target session id \"\(edge.toSessionId)\" must be declared in workstream nodes."
        )
      )
    }
  }

  if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId,
    declaredSessionIds.contains(workstream.entrySessionId),
    declaredSessionIds.contains(requiredCloseoutSessionId),
    !isReachable(
      from: workstream.entrySessionId,
      to: requiredCloseoutSessionId,
      edges: workstream.edges
    )
  {
    errors.append(
      ValidationError(
        entityType: .directive,
        entityId: directiveId,
        field: "workstream.requiredCloseoutSessionId",
        missingId: requiredCloseoutSessionId,
        expectedPath: "Sessions/\(requiredCloseoutSessionId).session.json",
        message:
          "Required closeout session id \"\(requiredCloseoutSessionId)\" is not reachable from entry session id \"\(workstream.entrySessionId)\"."
      )
    )
  }

  return errors
}

private func duplicateValue(in values: [String]) -> String? {
  var seen: Set<String> = []

  for value in values {
    if seen.contains(value) {
      return value
    }
    seen.insert(value)
  }

  return nil
}

private func isReachable(
  from start: String,
  to target: String,
  edges: [Directive.Workstream.Edge]
) -> Bool {
  if start == target {
    return true
  }

  var queue = [start]
  var visited: Set<String> = [start]
  let adjacency = Dictionary(grouping: edges, by: \.fromSessionId)

  while !queue.isEmpty {
    let current = queue.removeFirst()

    for edge in adjacency[current] ?? [] {
      if edge.toSessionId == target {
        return true
      }

      if !visited.contains(edge.toSessionId) {
        visited.insert(edge.toSessionId)
        queue.append(edge.toSessionId)
      }
    }
  }

  return false
}

/// Lists all unique essential ids found across scope load order.
private func listEssentialIds(scopes: ScopeSet, fileManager: FileManager) -> [String] {
  var ids: Set<String> = []

  for root in scopes.loadOrder {
    let essentialsURL = root.appendingPathComponent("Packs/essentials")
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: essentialsURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      continue
    }

    if let files = try? fileManager.contentsOfDirectory(
      at: essentialsURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) {
      for file in files where file.pathExtension == "md" {
        ids.insert(file.deletingPathExtension().lastPathComponent)
      }
    }
  }

  return ids.sorted()
}
