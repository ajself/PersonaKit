import Foundation
import Testing

@testable import ContextCore

struct WorkspaceEntityJSONSchemaValidatorTests {
  @Test
  func validateAcceptsValidPersonaJSON() throws {
    let fixtureURL = fixtureKitRootURL()
      .appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    let jsonData = try Data(contentsOf: fixtureURL)
    let validator = WorkspaceEntityJSONSchemaValidator()

    try validator.validate(
      jsonData: jsonData,
      entityType: .persona
    )
  }

  @Test
  func validateReportsSchemaFailureForInvalidJSON() throws {
    let jsonData = Data(
      """
      {
        "summary": "Missing required id field."
      }
      """.utf8
    )
    let validator = WorkspaceEntityJSONSchemaValidator()

    do {
      try validator.validate(
        jsonData: jsonData,
        entityType: .persona
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Schema validation failed"))
      #expect(error.message.contains("Missing required property"))
    }
  }
}
