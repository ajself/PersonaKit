import ContextCore
import Foundation

/// Schema-backed editable PersonaKit entity kinds used by Studio raw JSON workflows.
public enum WorkspaceLibraryEntityType: String, CaseIterable, Sendable {
  case persona
  case kit
  case directive
  case reference
  case skill

  /// Display label used in Studio editing UI.
  public var displayName: String {
    switch self {
    case .persona:
      return "Persona"
    case .kit:
      return "Kit"
    case .directive:
      return "Directive"
    case .reference:
      return "Reference"
    case .skill:
      return "Skill"
    }
  }

  /// Packs subdirectory for this entity kind.
  public var directoryName: String {
    switch self {
    case .persona:
      return "personas"
    case .kit:
      return "kits"
    case .directive:
      return "directives"
    case .reference:
      return "references"
    case .skill:
      return "skills"
    }
  }

  /// Expected JSON file suffix for this entity kind.
  public var fileSuffix: String {
    switch self {
    case .persona:
      return ".persona.json"
    case .kit:
      return ".kit.json"
    case .directive:
      return ".directive.json"
    case .reference:
      return ".reference.json"
    case .skill:
      return ".skill.json"
    }
  }

  fileprivate var schemaName: String {
    switch self {
    case .persona:
      return "persona.schema.json"
    case .kit:
      return "kit.schema.json"
    case .directive:
      return "directive.schema.json"
    case .reference:
      return "reference.schema.json"
    case .skill:
      return "skill.schema.json"
    }
  }
}

/// Contract for validating raw JSON bytes against bundled PersonaKit entity schemas.
public protocol WorkspaceEntityJSONSchemaValidating: Sendable {
  func validate(
    jsonData: Data,
    entityType: WorkspaceLibraryEntityType
  ) throws
}

/// Public schema validation bridge used by Studio raw JSON editing.
public struct WorkspaceEntityJSONSchemaValidator: WorkspaceEntityJSONSchemaValidating, Sendable {
  public init() {}

  /// Validates raw JSON bytes against the schema for a given entity kind.
  ///
  /// - Parameters:
  ///   - jsonData: UTF-8 JSON bytes.
  ///   - entityType: Entity kind mapped to a bundled schema.
  /// - Throws: ``WorkspaceSnapshotBuildError`` when JSON is invalid or schema checks fail.
  public func validate(
    jsonData: Data,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    let relativePath = "Packs/\(entityType.directoryName)/draft\(entityType.fileSuffix)"
    let errors = SchemaValidationBridge.validate(
      jsonData: jsonData,
      schemaName: entityType.schemaName,
      relativePath: relativePath
    )

    guard errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: Self.validationMessage(for: errors)
      )
    }
  }

  private static func validationMessage(
    for errors: [SchemaValidationIssue]
  ) -> String {
    let details = errors.prefix(3).map { error in
      if let instanceLocation = error.instanceLocation {
        return "\(error.schemaName): \(error.message) location=\(instanceLocation)"
      }

      return "\(error.schemaName): \(error.message)"
    }
    .joined(separator: " ")

    return "Schema validation failed. \(details)"
  }
}
