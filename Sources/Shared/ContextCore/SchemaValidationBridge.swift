import Foundation

/// Public schema validation issue exposed to workspace-facing modules.
public struct SchemaValidationIssue: Equatable, Sendable {
  public let schemaName: String
  public let message: String
  public let instanceLocation: String?

  public init(
    schemaName: String,
    message: String,
    instanceLocation: String?
  ) {
    self.schemaName = schemaName
    self.message = message
    self.instanceLocation = instanceLocation
  }
}

/// Public bridge for validating raw JSON bytes against bundled schemas.
public enum SchemaValidationBridge {
  public static func validate(
    jsonData: Data,
    schemaName: String,
    relativePath: String
  ) -> [SchemaValidationIssue] {
    SchemaValidator.validate(
      jsonData: jsonData,
      schemaName: schemaName,
      relativePath: relativePath
    )
    .map { error in
      SchemaValidationIssue(
        schemaName: error.schemaName,
        message: error.message,
        instanceLocation: error.instanceLocation
      )
    }
  }
}
