import CryptoKit
import Foundation

public enum PersonaChangeKind: String, Sendable, Hashable {
  case added
  case removed
  case modified
}

public struct PersonaChange: Sendable, Hashable {
  public let id: String
  public let name: String?
  public let kind: PersonaChangeKind

  public init(id: String, name: String?, kind: PersonaChangeKind) {
    self.id = id
    self.name = name
    self.kind = kind
  }
}

public struct PackDiff: Sendable, Hashable {
  public let added: [PersonaChange]
  public let removed: [PersonaChange]
  public let modified: [PersonaChange]

  public init(added: [PersonaChange], removed: [PersonaChange], modified: [PersonaChange]) {
    self.added = added
    self.removed = removed
    self.modified = modified
  }
}

public struct PersonaDiffRecord: Sendable, Hashable {
  public let key: String
  public let id: String
  public let name: String?
  public let contentHash: String

  public init(key: String, id: String, name: String?, contentHash: String) {
    self.key = key
    self.id = id
    self.name = name
    self.contentHash = contentHash
  }
}

public enum PackDiffBuilder {
  public static func diff(left: [PersonaDiffRecord], right: [PersonaDiffRecord]) -> PackDiff {
    let leftByKey = indexByKey(left)
    let rightByKey = indexByKey(right)

    let leftKeys = Set(leftByKey.keys)
    let rightKeys = Set(rightByKey.keys)

    let added = rightKeys.subtracting(leftKeys).compactMap { key -> PersonaChange? in
      guard let record = rightByKey[key] else { return nil }
      return PersonaChange(id: record.id, name: record.name, kind: .added)
    }

    let removed = leftKeys.subtracting(rightKeys).compactMap { key -> PersonaChange? in
      guard let record = leftByKey[key] else { return nil }
      return PersonaChange(id: record.id, name: record.name, kind: .removed)
    }

    let modified = leftKeys.intersection(rightKeys).compactMap { key -> PersonaChange? in
      guard let leftRecord = leftByKey[key],
        let rightRecord = rightByKey[key],
        leftRecord.contentHash != rightRecord.contentHash
      else { return nil }
      return PersonaChange(id: rightRecord.id, name: rightRecord.name, kind: .modified)
    }

    return PackDiff(
      added: sortChanges(added),
      removed: sortChanges(removed),
      modified: sortChanges(modified)
    )
  }

  public static func personaKey(id: String, fileURL: URL?) -> String {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      return trimmed
    }
    guard let fileURL else { return "" }
    return fileURL.lastPathComponent
  }

  public static func contentHash(for persona: Persona) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(persona) else {
      return ""
    }
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func indexByKey(_ records: [PersonaDiffRecord]) -> [String: PersonaDiffRecord] {
    let sorted = records.sorted { lhs, rhs in
      if lhs.key != rhs.key { return lhs.key < rhs.key }
      if lhs.id != rhs.id { return lhs.id < rhs.id }
      return (lhs.name ?? "") < (rhs.name ?? "")
    }
    var indexed: [String: PersonaDiffRecord] = [:]
    for record in sorted {
      indexed[record.key] = record
    }
    return indexed
  }

  private static func sortChanges(_ changes: [PersonaChange]) -> [PersonaChange] {
    changes.sorted { lhs, rhs in
      if lhs.id != rhs.id { return lhs.id < rhs.id }
      return (lhs.name ?? "") < (rhs.name ?? "")
    }
  }
}
