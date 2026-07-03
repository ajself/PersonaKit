import Foundation

struct ValidatorBootstrapResult {
  let registry: Registry?
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
        errors: errors,
        hasSchemaErrors: !schemaErrors.isEmpty
      )
    }

    return ValidatorBootstrapResult(
      registry: registry,
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
    return ValidationError(
      entityType: .session,
      entityId: sessionId,
      field: error.field,
      missingId: error.missingId,
      expectedPath: nil,
      message: error.message,
      referencesUnresolvedID: error.isUnresolvedReference
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
    case .discoveryPathNotDirectory(let path), .discoveryReadFailed(let path, _):
      field = "sessionFile"
      missingId = sessionId
      expectedPath = path
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

  static func sessionDiscoveryValidationError(for error: SessionFileError) -> ValidationError {
    let expectedPath: String?

    switch error {
    case .discoveryPathNotDirectory(let path), .discoveryReadFailed(let path, _):
      expectedPath = path
    case .notFound, .decodeFailed, .idMismatch, .invalidSessionId, .invalidSessionPath:
      expectedPath = nil
    }

    return ValidationError(
      entityType: .session,
      entityId: nil,
      field: "sessionFile",
      missingId: nil,
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
    case .skill:
      return .skill
    case .packsRoot:
      return .kit
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
    if schemaPath.contains("/skills/") || schemaPath.hasSuffix(".skill.json") {
      return .skill
    }
    return .kit
  }

  static func checkCancellation() throws {
    if Task.isCancelled {
      throw CancellationError()
    }
  }
}
