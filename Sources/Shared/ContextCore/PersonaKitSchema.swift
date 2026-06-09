import Foundation

/// Read-only access to the bundled JSON Schemas that ship with ContextCore.
///
/// `Bundle.module` resolves the `Schemas/` resources only from inside this
/// target, so callers in other targets reach the raw schema text through here
/// rather than re-implementing bundle access. The supported entity set is the
/// authored-JSON entities defined by ``SchemaValidator``'s mappings — the single
/// source of truth shared with pack validation.
public enum PersonaKitSchema {
  /// Authored-JSON entity types that ship a bundled JSON Schema, in stable order.
  public static let supportedEntities: [String] = SchemaValidator.mappings.map(\.entity)

  /// Returns the raw bundled JSON Schema text for an authored-JSON entity type.
  ///
  /// - Parameter entity: Entity type identifier (for example, `persona`).
  /// - Returns: The schema file contents verbatim, or `nil` if the entity has no
  ///   bundled schema or the resource cannot be read.
  public static func json(for entity: String) -> String? {
    guard let mapping = SchemaValidator.mappings.first(where: { $0.entity == entity }),
      let url = Bundle.module.url(forResource: mapping.schemaName, withExtension: nil),
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }

    return String(decoding: data, as: UTF8.self)
  }
}
