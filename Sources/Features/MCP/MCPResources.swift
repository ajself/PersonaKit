import ContextCore
import Foundation
import MCP

/// Resource URI parse failures for `personakit://` resource lookups.
enum MCPResourceURIError: Error, LocalizedError, Equatable {
  case invalidURI(String)
  case invalidScheme(String)
  case unsupportedHost(String)
  case invalidPacksURI(String)
  case invalidEssentialsURI(String)
  case invalidCatalogURI(String)
  case invalidSegment(String)
  case unknownPacksType(String)
  case unknownCatalogType(String)

  var errorDescription: String? {
    switch self {
    case .invalidURI(let uri):
      return "Invalid URI: \(uri)"
    case .invalidScheme(let scheme):
      return "Unsupported URI scheme: \(scheme)"
    case .unsupportedHost(let host):
      return "Unsupported URI host: \(host)"
    case .invalidPacksURI(let uri):
      return "Invalid packs URI: \(uri)"
    case .invalidEssentialsURI(let uri):
      return "Invalid essentials URI: \(uri)"
    case .invalidCatalogURI(let uri):
      return "Invalid catalog URI: \(uri)"
    case .invalidSegment(let segment):
      return "Invalid URI path segment: \(segment)"
    case .unknownPacksType(let type):
      return "Unknown packs type: \(type)"
    case .unknownCatalogType(let type):
      return "Unknown catalog type: \(type)"
    }
  }
}

/// Supported pack entity categories for MCP resource URIs.
enum MCPPackResourceType: String, CaseIterable, Equatable {
  case personas
  case kits
  case directives
  case intents
  case skills

  var suffix: String {
    switch self {
    case .personas:
      return ".persona.json"
    case .kits:
      return ".kit.json"
    case .directives:
      return ".directive.json"
    case .intents:
      return ".intent.json"
    case .skills:
      return ".skill.json"
    }
  }

  var mimeType: String {
    return "application/json"
  }
}

/// Supported MCP catalog resources for API/domain discovery.
enum MCPCatalogResourceType: String, CaseIterable, Equatable {
  case index
  case personas
  case kits
  case directives
  case intents
  case skills
  case essentials
  case sessions
  case api

  var mimeType: String {
    return "application/json"
  }
}

/// Parsed resource reference describing a pack JSON or essential markdown file.
enum MCPResourceReference: Equatable {
  case pack(type: MCPPackResourceType, id: String)
  case essential(id: String)
  case catalog(type: MCPCatalogResourceType)

  var uri: String {
    switch self {
    case .pack(let type, let id):
      return "personakit://packs/\(type.rawValue)/\(encodeComponent(id))"
    case .essential(let id):
      return "personakit://essentials/\(encodeComponent(id))"
    case .catalog(let type):
      return "personakit://catalog/\(encodeComponent(type.rawValue))"
    }
  }

  var relativePath: String {
    switch self {
    case .pack(let type, let id):
      return "Packs/\(type.rawValue)/\(id)\(type.suffix)"
    case .essential(let id):
      return "Packs/essentials/\(id).md"
    case .catalog(let type):
      return "catalog/\(type.rawValue)"
    }
  }

  var mimeType: String {
    switch self {
    case .pack(let type, _):
      return type.mimeType
    case .essential:
      return "text/markdown"
    case .catalog(let type):
      return type.mimeType
    }
  }

  var name: String {
    switch self {
    case .pack(_, let id):
      return id
    case .essential(let id):
      return id
    case .catalog(let type):
      return "catalog-\(type.rawValue)"
    }
  }

  /// Parses and validates a `personakit://` resource URI.
  static func parse(uri: String) throws -> MCPResourceReference {
    guard let components = URLComponents(string: uri) else {
      throw MCPResourceURIError.invalidURI(uri)
    }
    let scheme = components.scheme ?? ""
    guard scheme == "personakit" else {
      throw MCPResourceURIError.invalidScheme(scheme)
    }

    let host = components.host ?? ""
    let segments = components.path
      .split(separator: "/")
      .map { decodeComponent(String($0)) }

    if host == "packs" {
      guard segments.count == 2 else {
        throw MCPResourceURIError.invalidPacksURI(uri)
      }
      let typeSegment = segments[0]
      let idSegment = segments[1]
      try validateSegment(typeSegment)
      try validateSegment(idSegment)

      guard let type = MCPPackResourceType(rawValue: typeSegment) else {
        throw MCPResourceURIError.unknownPacksType(typeSegment)
      }
      return .pack(type: type, id: idSegment)
    }

    if host == "essentials" {
      guard segments.count == 1 else {
        throw MCPResourceURIError.invalidEssentialsURI(uri)
      }
      let idSegment = segments[0]
      try validateSegment(idSegment)
      return .essential(id: idSegment)
    }

    if host == "catalog" {
      guard segments.count == 1 else {
        throw MCPResourceURIError.invalidCatalogURI(uri)
      }
      let typeSegment = segments[0]
      try validateSegment(typeSegment)
      guard let type = MCPCatalogResourceType(rawValue: typeSegment) else {
        throw MCPResourceURIError.unknownCatalogType(typeSegment)
      }
      return .catalog(type: type)
    }

    throw MCPResourceURIError.unsupportedHost(host)
  }
}

/// Resource metadata entry used to build MCP `Resource` values.
struct MCPResourceEntry: Equatable {
  let uri: String
  let name: String
  let mimeType: String

  static func sorted(_ entries: [MCPResourceEntry]) -> [MCPResourceEntry] {
    return entries.sorted { $0.uri < $1.uri }
  }
}

/// MCP resource handler service for listing and reading PersonaKit assets.
struct MCPResourceService: Sendable {
  let registry: Registry
  let scopes: ScopeSet

  init(
    registry: Registry,
    scopes: ScopeSet
  ) {
    self.registry = registry
    self.scopes = scopes
  }

  /// Lists available resources with deterministic URI ordering.
  func listResources() throws -> [Resource] {
    var entries: [MCPResourceEntry] = []

    for catalog in MCPCatalogResourceType.allCases {
      entries.append(entry(for: .catalog(type: catalog)))
    }

    for persona in registry.personas {
      entries.append(entry(for: .pack(type: .personas, id: persona.id)))
    }
    for kit in registry.kits {
      entries.append(entry(for: .pack(type: .kits, id: kit.id)))
    }
    for directive in registry.directives {
      entries.append(entry(for: .pack(type: .directives, id: directive.id)))
    }
    for intent in registry.intentTemplates {
      entries.append(entry(for: .pack(type: .intents, id: intent.id)))
    }
    for skill in registry.skills {
      entries.append(entry(for: .pack(type: .skills, id: skill.id)))
    }

    let essentialIds = try listEssentialIds(scopes: scopes, fileManager: .default)
    for essentialId in essentialIds {
      entries.append(entry(for: .essential(id: essentialId)))
    }

    return MCPResourceEntry.sorted(entries).map { entry in
      Resource(
        name: entry.name,
        uri: entry.uri,
        mimeType: entry.mimeType
      )
    }
  }

  /// Reads a resource by URI and returns text content with metadata.
  func readResource(uri: String) throws -> Resource.Content {
    let reference: MCPResourceReference
    do {
      reference = try MCPResourceReference.parse(uri: uri)
    } catch let error as MCPResourceURIError {
      throw MCPError.invalidParams(error.localizedDescription)
    }
    if case .catalog(let type) = reference {
      let text = try readCatalogResource(type: type)
      return Resource.Content.text(text, uri: reference.uri, mimeType: reference.mimeType)
    }

    let relativePath = reference.relativePath
    guard let fileURL = resolveFileURL(reference: reference, scopes: scopes, fileManager: .default)
    else {
      throw MCPError.invalidParams(
        "Resource not found for URI \(uri); expected \(relativePath)"
      )
    }

    let text: String
    do {
      text = try String(contentsOf: fileURL, encoding: .utf8)
    } catch {
      throw MCPError.internalError("Failed to read \(relativePath).")
    }

    return Resource.Content.text(text, uri: reference.uri, mimeType: reference.mimeType)
  }

  private func entry(for reference: MCPResourceReference) -> MCPResourceEntry {
    MCPResourceEntry(
      uri: reference.uri,
      name: reference.name,
      mimeType: reference.mimeType
    )
  }
}

private struct MCPCatalogScope: Encodable {
  let projectRoot: String?
  let globalRoot: String?
  let loadOrder: [String]
  let resolutionOrder: [String]
}

private struct MCPCatalogIndexEntry: Encodable {
  let type: String
  let count: Int
  let uri: String
}

private struct MCPCatalogIndexPayload: Encodable {
  let schemaVersion: Int
  let scope: MCPCatalogScope
  let counts: [String: Int]
  let resources: [MCPCatalogIndexEntry]
}

private struct MCPCatalogListPayload: Encodable {
  let schemaVersion: Int
  let type: String
  let ids: [String]
}

private struct MCPCatalogSessionSummary: Encodable {
  let id: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

private struct MCPCatalogSessionPayload: Encodable {
  let schemaVersion: Int
  let type: String
  let sessions: [MCPCatalogSessionSummary]
}

private struct MCPCatalogAPIResourceSummary: Encodable {
  let uri: String
  let description: String
}

private struct MCPCatalogAPIPayload: Encodable {
  let schemaVersion: Int
  let type: String
  let resources: [MCPCatalogAPIResourceSummary]
}

extension MCPResourceService {
  func readCatalogResource(type: MCPCatalogResourceType) throws -> String {
    switch type {
    case .index:
      return try encodeCatalogJSON(catalogIndexPayload())
    case .personas:
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.personas.map(\.id)
        )
      )
    case .kits:
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.kits.map(\.id)
        )
      )
    case .directives:
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.directives.map(\.id)
        )
      )
    case .intents:
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.intentTemplates.map(\.id)
        )
      )
    case .skills:
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.skills.map(\.id)
        )
      )
    case .essentials:
      let ids = try listEssentialIds(scopes: scopes, fileManager: .default)
      return try encodeCatalogJSON(
        MCPCatalogListPayload(
          schemaVersion: 1,
          type: type.rawValue,
          ids: ids
        )
      )
    case .sessions:
      let sessions = try listSessionSummaries(scopes: scopes, fileManager: .default)
      return try encodeCatalogJSON(
        MCPCatalogSessionPayload(
          schemaVersion: 1,
          type: type.rawValue,
          sessions: sessions
        )
      )
    case .api:
      return try encodeCatalogJSON(catalogAPIPayload())
    }
  }

  private func catalogIndexPayload() throws -> MCPCatalogIndexPayload {
    let essentials = try listEssentialIds(scopes: scopes, fileManager: .default)
    let sessions = try listSessionSummaries(scopes: scopes, fileManager: .default)
    let resources = MCPCatalogResourceType.allCases.map { type in
      MCPCatalogIndexEntry(
        type: type.rawValue,
        count: count(for: type, essentialsCount: essentials.count, sessionsCount: sessions.count),
        uri: MCPResourceReference.catalog(type: type).uri
      )
    }

    return MCPCatalogIndexPayload(
      schemaVersion: 1,
      scope: MCPCatalogScope(
        projectRoot: scopes.projectScopeURL?.path,
        globalRoot: scopes.globalScopeURL?.path,
        loadOrder: scopes.loadOrder.map(\.path),
        resolutionOrder: scopes.resolutionOrder.map(\.path)
      ),
      counts: [
        "personas": registry.personas.count,
        "kits": registry.kits.count,
        "directives": registry.directives.count,
        "intents": registry.intentTemplates.count,
        "skills": registry.skills.count,
        "essentials": essentials.count,
        "sessions": sessions.count,
      ],
      resources: resources
    )
  }

  private func catalogAPIPayload() -> MCPCatalogAPIPayload {
    let resources = MCPCatalogResourceType.allCases.map { type in
      MCPCatalogAPIResourceSummary(
        uri: MCPResourceReference.catalog(type: type).uri,
        description: catalogDescription(type: type)
      )
    }

    return MCPCatalogAPIPayload(
      schemaVersion: 1,
      type: "api",
      resources: resources
    )
  }

  private func count(
    for type: MCPCatalogResourceType,
    essentialsCount: Int,
    sessionsCount: Int
  ) -> Int {
    switch type {
    case .index, .api:
      return 1
    case .personas:
      return registry.personas.count
    case .kits:
      return registry.kits.count
    case .directives:
      return registry.directives.count
    case .intents:
      return registry.intentTemplates.count
    case .skills:
      return registry.skills.count
    case .essentials:
      return essentialsCount
    case .sessions:
      return sessionsCount
    }
  }
}

private func catalogDescription(type: MCPCatalogResourceType) -> String {
  switch type {
  case .index:
    return "Top-level catalog index with counts, scope metadata, and type URIs."
  case .personas:
    return "List of persona ids available in the active scope set."
  case .kits:
    return "List of kit ids available in the active scope set."
  case .directives:
    return "List of directive ids available in the active scope set."
  case .intents:
    return "List of intent template ids available in the active scope set."
  case .skills:
    return "List of skill ids available in the active scope set."
  case .essentials:
    return "List of essential markdown ids available in the active scope set."
  case .sessions:
    return "Session summaries with persona, directive, and optional kit overrides."
  case .api:
    return "Catalog API overview for MCP discovery and navigation."
  }
}

private func encodeCatalogJSON<T: Encodable>(_ payload: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data: Data
  do {
    data = try encoder.encode(payload)
  } catch {
    throw MCPError.internalError("Failed to encode catalog resource.")
  }

  guard let text = String(data: data, encoding: .utf8) else {
    throw MCPError.internalError("Failed to encode catalog resource.")
  }

  return text
}

private func encodeComponent(_ value: String) -> String {
  var allowed = CharacterSet.urlPathAllowed
  allowed.remove(charactersIn: "/")
  return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

private func decodeComponent(_ value: String) -> String {
  value.removingPercentEncoding ?? value
}

private func validateSegment(_ segment: String) throws {
  guard !segment.isEmpty, segment != ".", segment != ".." else {
    throw MCPResourceURIError.invalidSegment(segment)
  }
  if segment.contains("/") || segment.contains("\\") {
    throw MCPResourceURIError.invalidSegment(segment)
  }
}

private func listEssentialIds(scopes: ScopeSet, fileManager: FileManager) throws -> [String] {
  var ids: Set<String> = []
  for root in scopes.loadOrder {
    let essentialsURL = root.appendingPathComponent("Packs/essentials")
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: essentialsURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      continue
    }

    let files: [URL]
    do {
      files = try fileManager.contentsOfDirectory(
        at: essentialsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    } catch {
      throw MCPError.internalError("Failed to read Packs/essentials directory.")
    }

    for file in files where file.pathExtension == "md" {
      ids.insert(file.deletingPathExtension().lastPathComponent)
    }
  }

  return ids.sorted()
}

private func listSessionSummaries(
  scopes: ScopeSet,
  fileManager: FileManager
) throws -> [MCPCatalogSessionSummary] {
  do {
    return try SessionFileLoader.list(scopes: scopes, fileManager: fileManager).map { session in
      MCPCatalogSessionSummary(
        id: session.id,
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: session.kitOverrides ?? []
      )
    }
  } catch {
    throw MCPError.internalError("Failed to load session files.")
  }
}

private func resolveFileURL(
  reference: MCPResourceReference,
  scopes: ScopeSet,
  fileManager: FileManager
) -> URL? {
  let relativePath = reference.relativePath
  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(relativePath)
    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }
  return nil
}
