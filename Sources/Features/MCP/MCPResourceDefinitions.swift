import Foundation

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
  case start
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
      return "personakit://packs/\(type.rawValue)/\(MCPResourceURIComponents.encode(id))"
    case .essential(let id):
      return "personakit://essentials/\(MCPResourceURIComponents.encode(id))"
    case .catalog(let type):
      return "personakit://catalog/\(MCPResourceURIComponents.encode(type.rawValue))"
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
      .map { MCPResourceURIComponents.decode(String($0)) }

    if host == "packs" {
      guard segments.count == 2 else {
        throw MCPResourceURIError.invalidPacksURI(uri)
      }
      let typeSegment = segments[0]
      let idSegment = segments[1]
      try MCPResourceURIComponents.validate(segment: typeSegment)
      try MCPResourceURIComponents.validate(segment: idSegment)

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
      try MCPResourceURIComponents.validate(segment: idSegment)
      return .essential(id: idSegment)
    }

    if host == "catalog" {
      guard segments.count == 1 else {
        throw MCPResourceURIError.invalidCatalogURI(uri)
      }
      let typeSegment = segments[0]
      try MCPResourceURIComponents.validate(segment: typeSegment)
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

enum MCPResourceURIComponents {
  static func encode(_ value: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }

  static func decode(_ value: String) -> String {
    return value.removingPercentEncoding ?? value
  }

  static func validate(segment: String) throws {
    guard !segment.isEmpty, segment != ".", segment != ".." else {
      throw MCPResourceURIError.invalidSegment(segment)
    }
    if segment.contains("/") || segment.contains("\\") {
      throw MCPResourceURIError.invalidSegment(segment)
    }
  }
}
