import Foundation

struct ValidatorBootstrapResult {
  let registry: Registry?
  let essentialIds: [String]
  let errors: [ValidationError]
  let hasSchemaErrors: Bool
}

enum ValidatorBootstrap {
  static func prepare(
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> ValidatorBootstrapResult {
    try ValidatorSupport.checkCancellation()

    let schemaErrors = SchemaValidator.validate(scopes: scopes, fileManager: fileManager)
    var errors = schemaErrors.map(ValidatorSupport.validationError(for:))

    let registry: Registry
    do {
      registry = try Registry.load(scopes: scopes, fileManager: fileManager)
    } catch let error as RegistryLoadError {
      errors.append(
        contentsOf: error.errors.map(ValidatorSupport.validationError(for:))
      )

      return ValidatorBootstrapResult(
        registry: nil,
        essentialIds: [],
        errors: errors,
        hasSchemaErrors: !schemaErrors.isEmpty
      )
    }

    return ValidatorBootstrapResult(
      registry: registry,
      essentialIds: ValidatorSupport.listEssentialIds(scopes: scopes, fileManager: fileManager),
      errors: errors,
      hasSchemaErrors: !schemaErrors.isEmpty
    )
  }
}

enum ValidatorSupport {
  static func validationError(for error: SchemaValidationError) -> ValidationError {
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

  static func validationError(for error: RegistryError) -> ValidationError {
    ValidationError(
      entityType: map(entityType: error.entityType),
      entityId: error.id,
      field: error.id == nil ? "file" : "id",
      missingId: nil,
      expectedPath: error.relativePath,
      message: error.message
    )
  }

  static func validationError(
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

  static func validationError(
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
      expectedPath = SessionFileLoader.expectedPath(for: sessionId)
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

  static func map(entityType: RegistryEntityType) -> ValidationEntityType {
    switch entityType {
    case .persona:
      return .persona
    case .kit:
      return .kit
    case .directive:
      return .directive
    case .intentTemplate:
      return .intent
    case .reference:
      return .reference
    case .skill:
      return .skill
    case .packsRoot:
      return .essentials
    }
  }

  static func map(schemaPath: String) -> ValidationEntityType {
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
    if schemaPath.contains("/references/") || schemaPath.hasSuffix(".reference.json") {
      return .reference
    }
    if schemaPath.contains("/skills/") || schemaPath.hasSuffix(".skill.json") {
      return .skill
    }
    return .essentials
  }

  static func checkCancellation() throws {
    if Task.isCancelled {
      throw CancellationError()
    }
  }

  static func listEssentialIds(
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> [String] {
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

  static func listReferenceIds(
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> [String] {
    var ids: Set<String> = []

    for root in scopes.loadOrder {
      let referencesURL = PersonaKitDirectory.referencesURL(root: root)
      var isDirectory: ObjCBool = false

      guard fileManager.fileExists(atPath: referencesURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }

      if let files = try? fileManager.contentsOfDirectory(
        at: referencesURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      ) {
        for file in files where file.lastPathComponent.hasSuffix(".reference.json") {
          let fileName = file.deletingPathExtension().lastPathComponent
          ids.insert((fileName as NSString).deletingPathExtension)
        }
      }
    }

    return ids.sorted()
  }
}
