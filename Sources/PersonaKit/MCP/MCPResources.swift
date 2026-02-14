import Foundation
import MCP

enum MCPResourceURIError: Error, LocalizedError, Equatable {
    case invalidURI(String)
    case invalidScheme(String)
    case unsupportedHost(String)
    case invalidPacksURI(String)
    case invalidEssentialsURI(String)
    case invalidSegment(String)
    case unknownPacksType(String)

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
        case .invalidSegment(let segment):
            return "Invalid URI path segment: \(segment)"
        case .unknownPacksType(let type):
            return "Unknown packs type: \(type)"
        }
    }
}

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

enum MCPResourceReference: Equatable {
    case pack(type: MCPPackResourceType, id: String)
    case essential(id: String)

    var uri: String {
        switch self {
        case .pack(let type, let id):
            return "personakit://packs/\(type.rawValue)/\(encodeComponent(id))"
        case .essential(let id):
            return "personakit://essentials/\(encodeComponent(id))"
        }
    }

    var relativePath: String {
        switch self {
        case .pack(let type, let id):
            return "Packs/\(type.rawValue)/\(id)\(type.suffix)"
        case .essential(let id):
            return "Packs/essentials/\(id).md"
        }
    }

    var mimeType: String {
        switch self {
        case .pack(let type, _):
            return type.mimeType
        case .essential:
            return "text/markdown"
        }
    }

    var name: String {
        switch self {
        case .pack(_, let id):
            return id
        case .essential(let id):
            return id
        }
    }

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

        throw MCPResourceURIError.unsupportedHost(host)
    }
}

struct MCPResourceEntry: Equatable {
    let uri: String
    let name: String
    let mimeType: String

    static func sorted(_ entries: [MCPResourceEntry]) -> [MCPResourceEntry] {
        return entries.sorted { $0.uri < $1.uri }
    }
}

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

    func listResources() throws -> [Resource] {
        var entries: [MCPResourceEntry] = []

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

    func readResource(uri: String) throws -> Resource.Content {
        let reference: MCPResourceReference
        do {
            reference = try MCPResourceReference.parse(uri: uri)
        } catch let error as MCPResourceURIError {
            throw MCPError.invalidParams(error.localizedDescription)
        }
        let relativePath = reference.relativePath
        guard let fileURL = resolveFileURL(reference: reference, scopes: scopes, fileManager: .default) else {
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
        guard fileManager.fileExists(atPath: essentialsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
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
