import Foundation

public enum PersonaMetadata {
  private static func tagSortKey(_ tag: String) -> (String, String) {
    (tag.lowercased(), tag)
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

public extension Persona {
  var about: String? {
    description
  }

  var sortedTags: [String] {
    PersonaMetadata.sortedTags(tags)
  }
}
