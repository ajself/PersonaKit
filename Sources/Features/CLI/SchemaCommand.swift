import ArgumentParser
import ContextCore
import Foundation

/// Authored-JSON entity types whose bundled JSON Schema can be printed.
///
/// These cases mirror ``SchemaValidator``'s schema mappings — the entities that
/// are authored as JSON and validated against a bundled schema. It is
/// deliberately not a copy of the create/list entity sets: there is no bundled
/// `session` schema, `common.schema.json` is a shared `$ref` base rather than a
/// user entity, and essentials are authored as markdown.
enum SchemaEntityType: String, CaseIterable, Codable, ExpressibleByArgument {
  case persona
  case kit
  case directive
  case reference
  case skill
}

/// Prints the bundled JSON Schema for an authored-JSON entity type.
struct SchemaCLICommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "schema",
    abstract: "Print the bundled JSON Schema for an entity type.",
    discussion: """
      Reads the schema bundled with PersonaKit (not workspace files), so it takes \
      no --root. Use it to see required fields and exact property names before \
      authoring JSON by hand: `personakit schema persona`.
      """
  )

  @Argument(help: "Entity type whose JSON Schema to print.")
  var entityType: SchemaEntityType

  func run() throws {
    guard let json = PersonaKitSchema.json(for: entityType.rawValue) else {
      throw CLIError.failure("No bundled schema for entity \"\(entityType.rawValue)\".")
    }

    // Emit the schema text verbatim; the bundled files already end with a newline.
    print(json, terminator: "")
  }
}
