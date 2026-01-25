import Foundation

public struct PersonaDescribeFailure: Error, Equatable {
  public let message: String
  public let exitCode: Int32

  public init(message: String, exitCode: Int32) {
    self.message = message
    self.exitCode = exitCode
  }
}

public struct PersonaDescriptor {
  public static func describe(
    personaID: String?,
    resolved: [String: ResolvedPersona],
    sourcesByID: [String: PersonaSource],
    packsByID: [String: PackMeta],
    baseURL: URL? = nil
  ) -> Result<String, PersonaDescribeFailure> {
    guard let personaID, let persona = resolved[personaID]?.persona else {
      return .failure(
        PersonaDescribeFailure(
          message: "Persona not found. Fix: run 'personapad list' and use a valid persona id.",
          exitCode: 2
        ))
    }

    let source = sourcesByID[persona.id]
    let pack = packsByID[persona.id]

    let lines = describeLines(persona: persona, source: source, pack: pack, baseURL: baseURL)
    return .success(lines.joined(separator: "\n"))
  }

  public static func describeLines(
    persona: Persona,
    source: PersonaSource?,
    pack: PackMeta?,
    baseURL: URL? = nil
  ) -> [String] {
    var lines: [String] = []
    lines.append("Name: \(persona.name)")
    lines.append("ID: \(persona.id)")

    if let about = persona.about, !about.isEmpty {
      lines.append("Description: \(about)")
    }

    let tags = sortedUniqueTags(from: persona.tags)
    if !tags.isEmpty {
      lines.append("Tags: \(tags.joined(separator: ", "))")
    }

    if let sourceLabel = sourceLabel(source: source, pack: pack, baseURL: baseURL) {
      lines.append("Source: \(sourceLabel)")
    }

    return lines
  }

  public static func sortedUniqueTags(from tags: [String]?) -> [String] {
    guard let tags, !tags.isEmpty else { return [] }
    let unique = Array(Set(tags))
    return PersonaMetadata.sortedTags(unique)
  }

  public static func sourceLabel(source: PersonaSource?, pack: PackMeta?, baseURL: URL?) -> String?
  {
    guard let source else {
      return packDisplayLabel(pack)
    }

    switch source.kind {
    case .builtIn:
      if let name = packName(pack) {
        return "Built-in pack (\(name))"
      }
      if let id = packID(pack) {
        return "Built-in pack (\(id))"
      }
      return "Built-in pack"
    case .user, .project:
      if let url = source.url {
        if let relative = relativePath(for: url, baseURL: baseURL) {
          return relative
        }
        return abbreviateHome(url.path)
      }
      return packDisplayLabel(pack) ?? source.kind.rawValue
    case .adhoc:
      return packDisplayLabel(pack) ?? source.kind.rawValue
    }
  }

  private static func packDisplayLabel(_ pack: PackMeta?) -> String? {
    if let name = packName(pack), let id = packID(pack), name != id {
      return "\(name) (\(id))"
    }
    return packName(pack) ?? packID(pack)
  }

  private static func packName(_ pack: PackMeta?) -> String? {
    guard let pack else { return nil }
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
  }

  private static func packID(_ pack: PackMeta?) -> String? {
    guard let pack else { return nil }
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    return id.isEmpty ? nil : id
  }

  private static func relativePath(for url: URL, baseURL: URL?) -> String? {
    guard let baseURL else { return nil }
    let basePath = baseURL.standardizedFileURL.path
    let targetPath = url.standardizedFileURL.path
    guard targetPath.hasPrefix(basePath) else { return nil }
    var relative = String(targetPath.dropFirst(basePath.count))
    if relative.hasPrefix("/") {
      relative.removeFirst()
    }
    return relative.isEmpty ? "." : relative
  }

  private static func abbreviateHome(_ path: String) -> String {
    let home = FileClientProvider().fileClient.homeDirectory().standardizedFileURL.path
    guard path.hasPrefix(home) else { return path }
    return "~" + path.dropFirst(home.count)
  }
}
