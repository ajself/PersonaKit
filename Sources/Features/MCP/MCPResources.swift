import ContextCore
import Foundation
import MCP

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

    let essentialIds = try MCPResourceFileSupport.listEssentialIds(
      scopes: scopes,
      fileManager: .default
    )
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
    guard let fileURL = MCPResourceFileSupport.resolveFileURL(
      reference: reference,
      scopes: scopes,
      fileManager: .default
    )
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

extension MCPResourceService {
  func readCatalogResource(type: MCPCatalogResourceType) throws -> String {
    switch type {
    case .index:
      return try MCPCatalogSupport.encodeJSON(catalogIndexPayload())
    case .personas:
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.personas.map(\.id)
        )
      )
    case .kits:
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.kits.map(\.id)
        )
      )
    case .directives:
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.directives.map(\.id)
        )
      )
    case .intents:
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.intentTemplates.map(\.id)
        )
      )
    case .skills:
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: registry.skills.map(\.id)
        )
      )
    case .essentials:
      let ids = try MCPResourceFileSupport.listEssentialIds(scopes: scopes, fileManager: .default)
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.List(
          schemaVersion: 1,
          type: type.rawValue,
          ids: ids
        )
      )
    case .sessions:
      let sessions = try MCPResourceFileSupport.listSessionSummaries(
        scopes: scopes,
        fileManager: .default
      )
      return try MCPCatalogSupport.encodeJSON(
        MCPCatalogPayloads.Sessions(
          schemaVersion: 1,
          type: type.rawValue,
          sessions: sessions
        )
      )
    case .api:
      return try MCPCatalogSupport.encodeJSON(catalogAPIPayload())
    }
  }

  private func catalogIndexPayload() throws -> MCPCatalogPayloads.Index {
    let essentials = try MCPResourceFileSupport.listEssentialIds(scopes: scopes, fileManager: .default)
    let sessions = try MCPResourceFileSupport.listSessionSummaries(
      scopes: scopes,
      fileManager: .default
    )
    let resources = MCPCatalogResourceType.allCases.map { type in
      MCPCatalogPayloads.IndexEntry(
        type: type.rawValue,
        count: count(for: type, essentialsCount: essentials.count, sessionsCount: sessions.count),
        uri: MCPResourceReference.catalog(type: type).uri
      )
    }

    return MCPCatalogPayloads.Index(
      schemaVersion: 1,
      scope: MCPCatalogPayloads.Scope(
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

  private func catalogAPIPayload() -> MCPCatalogPayloads.API {
    let resources = MCPCatalogResourceType.allCases.map { type in
      MCPCatalogPayloads.APIResourceSummary(
        uri: MCPResourceReference.catalog(type: type).uri,
        description: MCPCatalogSupport.description(for: type)
      )
    }

    return MCPCatalogPayloads.API(
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

enum MCPResourceFileSupport {
  static func listEssentialIds(scopes: ScopeSet, fileManager: FileManager) throws -> [String] {
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

  static func listSessionSummaries(
    scopes: ScopeSet,
    fileManager: FileManager
  ) throws -> [MCPCatalogPayloads.SessionSummary] {
    do {
      return try SessionFileLoader.list(scopes: scopes, fileManager: fileManager).map { session in
        MCPCatalogPayloads.SessionSummary(
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

  static func resolveFileURL(
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
}
