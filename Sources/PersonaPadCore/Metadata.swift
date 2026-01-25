import Foundation

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

  private struct PersonaSortKey: Comparable {
    let nameNormalized: String
    let name: String
    let idNormalized: String
    let id: String

    static func < (lhs: PersonaSortKey, rhs: PersonaSortKey) -> Bool {
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

  public static func personaSortKey(_ persona: Persona) -> PersonaSortKey {
    PersonaSortKey(
      nameNormalized: persona.name.lowercased(),
      name: persona.name,
      idNormalized: persona.id.lowercased(),
      id: persona.id
    )
  }

  public static func sortedTags(_ tags: [String]?) -> [String] {
    guard let tags, !tags.isEmpty else { return [] }
    return tags.sorted { tagSortKey($0) < tagSortKey($1) }
  }

  public static func sortedUniqueTags(from personas: [Persona]) -> [String] {
    let unique = Set(personas.flatMap { $0.tags ?? [] })
    return sortedTags(Array(unique))
  }
}

extension Persona {
  public var about: String? {
    description
  }

  public var sortedTags: [String] {
    PersonaMetadata.sortedTags(tags)
  }
}
