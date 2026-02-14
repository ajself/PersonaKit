import Foundation

/// Entity categories used for deterministic validation reporting.
enum ValidationEntityType: String {
  case persona
  case kit
  case directive
  case intent
  case skill
  case essentials

  /// Stable sort priority used when ordering validation errors.
  var sortOrder: Int {
    switch self {
    case .persona:
      return 1
    case .kit:
      return 2
    case .directive:
      return 3
    case .intent:
      return 4
    case .skill:
      return 5
    case .essentials:
      return 6
    }
  }
}

/// Structured validation issue for a single entity reference or schema violation.
struct ValidationError: Error, Equatable {
  let entityType: ValidationEntityType
  let entityId: String?
  let field: String
  let missingId: String?
  let expectedPath: String?
  let message: String

  /// Renders a stable single-line description for CLI and MCP output.
  func lineDescription() -> String {
    var parts: [String] = [entityType.rawValue]

    if let entityId {
      parts.append(entityId)
    }

    parts.append(field + ":")
    parts.append(message)

    if let missingId {
      parts.append("missingId=\(missingId)")
    }

    if let expectedPath {
      parts.append("expectedPath=\(expectedPath)")
    }

    return parts.joined(separator: " ")
  }
}

/// Count summary for loaded entities encountered during validation.
struct ValidationCounts: Equatable {
  let personas: Int
  let kits: Int
  let directives: Int
  let intents: Int
  let skills: Int
  let essentials: Int

  static let zero = ValidationCounts(
    personas: 0,
    kits: 0,
    directives: 0,
    intents: 0,
    skills: 0,
    essentials: 0
  )
}

/// Deterministic validation result including entity counts and sorted errors.
struct ValidationResult: Equatable {
  let counts: ValidationCounts
  let errors: [ValidationError]

  /// Human-readable summary string used in user-facing output.
  var summary: String {
    return
      "Validation summary: personas=\(counts.personas) kits=\(counts.kits) directives=\(counts.directives) intents=\(counts.intents) skills=\(counts.skills) essentials=\(counts.essentials) errors=\(errors.count)"
  }

  /// Creates a validation result and sorts errors for stable output.
  init(counts: ValidationCounts, errors: [ValidationError]) {
    self.counts = counts
    self.errors = ValidationResult.sort(errors: errors)
  }

  private static func sort(errors: [ValidationError]) -> [ValidationError] {
    return errors.sorted { lhs, rhs in
      if lhs.entityType.sortOrder != rhs.entityType.sortOrder {
        return lhs.entityType.sortOrder < rhs.entityType.sortOrder
      }

      let lhsId = lhs.entityId ?? ""
      let rhsId = rhs.entityId ?? ""
      if lhsId != rhsId {
        return lhsId < rhsId
      }

      if lhs.field != rhs.field {
        return lhs.field < rhs.field
      }

      let lhsMissing = lhs.missingId ?? ""
      let rhsMissing = rhs.missingId ?? ""
      if lhsMissing != rhsMissing {
        return lhsMissing < rhsMissing
      }

      let lhsPath = lhs.expectedPath ?? ""
      let rhsPath = rhs.expectedPath ?? ""
      if lhsPath != rhsPath {
        return lhsPath < rhsPath
      }

      return lhs.message < rhs.message
    }
  }
}

/// Performs schema and cross-reference validation for PersonaKit pack data.
struct Validator {
  /// Validates a single root as project scope only.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory containing `Packs/`.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Deterministic validation result.
  static func validate(root: URL, fileManager: FileManager = .default) throws -> ValidationResult {
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
  static func validate(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws
    -> ValidationResult
  {
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
    }

    for kit in registry.kits {
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
        if resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager) == nil {
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
    }

    for intent in registry.intentTemplates {
      for essentialId in intent.includesEssentialIds {
        let expectedPath = "Packs/essentials/\(essentialId).md"
        if resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager) == nil {
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
}

/// Resolves an essential id to the first matching file in resolution order.
private func resolveEssentialURL(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> URL? {
  let expectedPath = "Packs/essentials/\(essentialId).md"

  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(expectedPath)

    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }

  return nil
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
