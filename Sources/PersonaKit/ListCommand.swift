import Foundation

enum ListEntityType: String, CaseIterable {
    case personas
    case kits
    case directives
    case intents
    case skills
    case essentials
}

struct ListCommand {
    static func list(
        root: URL,
        entityType: ListEntityType,
        fileManager: FileManager = .default
    ) throws -> String {
        try list(
            scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
            entityType: entityType,
            fileManager: fileManager
        )
    }

    static func list(
        scopes: ScopeSet,
        entityType: ListEntityType,
        fileManager: FileManager = .default
    ) throws -> String {
        let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
        let lines: [String]

        switch entityType {
        case .personas:
            lines = registry.personas.map { formatLine(id: $0.id, name: $0.name) }
        case .kits:
            lines = registry.kits.map { formatLine(id: $0.id, name: $0.name) }
        case .directives:
            lines = registry.directives.map { formatLine(id: $0.id, name: $0.title) }
        case .intents:
            lines = registry.intentTemplates.map { formatLine(id: $0.id, name: $0.name) }
        case .skills:
            lines = registry.skills.map { formatLine(id: $0.id, name: $0.name) }
        case .essentials:
            lines = try listEssentials(scopes: scopes, fileManager: fileManager)
        }

        return lines.joined(separator: "\n")
    }

    private static func formatLine(id: String, name: String?) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedName.isEmpty else {
            return id
        }
        return "\(id) — \(trimmedName)"
    }

    private static func listEssentials(scopes: ScopeSet, fileManager: FileManager) throws -> [String] {
        var ids: Set<String> = []
        for root in scopes.loadOrder {
            let essentialsURL = root.appendingPathComponent("Packs/essentials")
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: essentialsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let files = try fileManager.contentsOfDirectory(
                at: essentialsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for file in files where file.pathExtension == "md" {
                ids.insert(file.deletingPathExtension().lastPathComponent)
            }
        }

        return ids.sorted()
    }
}
