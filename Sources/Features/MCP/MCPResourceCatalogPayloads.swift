import Foundation
import MCP

enum MCPCatalogPayloads {
  struct Start: Encodable {
    let schemaVersion: Int
    let type: String
    let purpose: String
    let safetyModel: [String]
    let quickStart: [StartStep]
    let commonFlows: [StartFlow]
    let resourceMap: [StartEntry]
    let toolMap: [StartEntry]
    let promptMap: [StartEntry]
    let antiPatterns: [String]
  }

  struct StartStep: Encodable {
    let order: Int
    let action: String
    let use: String
  }

  struct StartFlow: Encodable {
    let goal: String
    let steps: [String]
  }

  struct StartEntry: Encodable {
    let id: String
    let use: String
  }

  struct Scope: Encodable {
    let projectRoot: String?
    let globalRoot: String?
    let loadOrder: [String]
    let resolutionOrder: [String]
  }

  struct IndexEntry: Encodable {
    let type: String
    let count: Int
    let uri: String
  }

  struct Index: Encodable {
    let schemaVersion: Int
    let scope: Scope
    let counts: [String: Int]
    let resources: [IndexEntry]
  }

  struct List: Encodable {
    let schemaVersion: Int
    let type: String
    let ids: [String]
  }

  struct SessionSummary: Encodable {
    let id: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]
  }

  struct Sessions: Encodable {
    let schemaVersion: Int
    let type: String
    let sessions: [SessionSummary]
  }

  struct APIResourceSummary: Encodable {
    let uri: String
    let description: String
  }

  struct API: Encodable {
    let schemaVersion: Int
    let type: String
    let firstReadUri: String
    let resources: [APIResourceSummary]
  }
}

enum MCPCatalogSupport {
  static func description(for type: MCPCatalogResourceType) -> String {
    switch type {
    case .start:
      return "Start-here guide for MCP discovery, grounding, safety, and common PersonaKit flows."
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

  static func encodeJSON<T: Encodable>(_ payload: T) throws -> String {
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
}
