import Foundation

/// Builds lookup indexes for persona sources and pack metadata.
public enum PersonaIndexBuilder {
  /// Returns deterministic lookup maps for sources and pack metadata keyed by persona id.
  public static func buildIndexes(
    sets: [PersonaSet]
  ) -> (sourcesByID: [String: PersonaSource], packsByID: [String: PackMeta]) {
    var sourcesByID: [String: PersonaSource] = [:]
    var packsByID: [String: PackMeta] = [:]

    for set in sets {
      for persona in set.personas {
        sourcesByID[persona.id] = set.source
        packsByID[persona.id] = set.pack
      }
    }

    return (sourcesByID: sourcesByID, packsByID: packsByID)
  }
}
