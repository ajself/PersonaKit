import Foundation

/// Helpers for sorting and presenting persona metadata.
public enum PersonaMetadata {
  private struct TagSortKey: Comparable {
    let normalized: String
    let original: String

    static func < (lhs: TagSortKey, rhs: TagSortKey) -> Bool {
      if lhs.normalized != rhs.normalized {
        return lhs.normalized < rhs.normalized
      }
      return lhs.original < rhs.original
    }
  }

  /// Deterministic sort key for persona lists.
  public struct PersonaSortKey: Comparable {
    let nameNormalized: String
    let name: String
    let idNormalized: String
    let id: String

    public static func < (lhs: PersonaSortKey, rhs: PersonaSortKey) -> Bool {
      if lhs.nameNormalized != rhs.nameNormalized {
        return lhs.nameNormalized < rhs.nameNormalized
      }
      if lhs.name != rhs.name {
        return lhs.name < rhs.name
      }
      if lhs.idNormalized != rhs.idNormalized {
        return lhs.idNormalized < rhs.idNormalized
      }
      return lhs.id < rhs.id
    }
  }

  private static func tagSortKey(_ tag: String) -> TagSortKey {
    TagSortKey(normalized: tag.lowercased(), original: tag)
  }

  /// Builds a sort key for the provided persona.
  public static func personaSortKey(_ persona: Persona) -> PersonaSortKey {
    PersonaSortKey(
      nameNormalized: persona.name.lowercased(),
      name: persona.name,
      idNormalized: persona.id.lowercased(),
      id: persona.id
    )
  }

  /// Sorts tags deterministically, preserving original case order.
  public static func sortedTags(_ tags: [String]?) -> [String] {
    guard let tags, !tags.isEmpty else { return [] }
    return tags.sorted { tagSortKey($0) < tagSortKey($1) }
  }

  /// Returns a sorted, unique tag list derived from personas.
  public static func sortedUniqueTags(from personas: [Persona]) -> [String] {
    let unique = Set(personas.flatMap { $0.tags ?? [] })
    return sortedTags(Array(unique))
  }
}

extension Persona {
  /// Convenience alias for ``Persona/description``.
  public var about: String? {
    description
  }

  /// Tags sorted using ``PersonaMetadata`` rules.
  public var sortedTags: [String] {
    PersonaMetadata.sortedTags(tags)
  }
}
