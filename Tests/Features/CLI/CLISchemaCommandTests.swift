import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLISchemaCommandTests {
  @Test
  func schemaPersonaEmitsValidJSONWithRequiredFields() throws {
    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "schema",
        "persona",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["$id"] as? String == "persona.schema.json")
    #expect(object["type"] as? String == "object")

    let required = try #require(object["required"] as? [String])
    #expect(required.contains("id"))
    #expect(required.contains("name"))
    #expect(required.contains("summary"))
  }

  @Test
  func schemaEmitsParseableSchemaForEverySupportedEntity() throws {
    for entityType in SchemaEntityType.allCases {
      var status: Int32 = 0
      let output = captureStdout {
        status = PersonaKitCLI().run(arguments: [
          "personakit",
          "schema",
          entityType.rawValue,
        ])
      }

      #expect(status == 0, "schema \(entityType.rawValue) should exit 0")

      let data = try #require(output.data(using: .utf8))
      let object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any],
        "schema \(entityType.rawValue) should emit a JSON object"
      )

      // Guards bundled-resource regressions for every supported schema entity.
      #expect(object["$schema"] != nil, "schema \(entityType.rawValue) should be a JSON Schema")
      #expect(object["type"] as? String == "object")
    }
  }

  @Test
  func schemaEntityTypeMatchesSupportedEntitiesSource() {
    #expect(SchemaEntityType.allCases.map(\.rawValue) == PersonaKitSchema.supportedEntities)
  }

  @Test
  func schemaUnsupportedEntityExitsNonZeroWithClearMessage() throws {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "schema",
        "session",
      ])
    }

    #expect(status != 0)
    #expect(stderrOutput.contains("session"))
  }
}
