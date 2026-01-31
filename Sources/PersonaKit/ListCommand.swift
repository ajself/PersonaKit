import Foundation

enum ListEntityType: String, CaseIterable {
    case personas
    case kits
    case tasks
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
        let registry = try Registry.load(root: root, fileManager: fileManager)
        let lines: [String]

        switch entityType {
        case .personas:
            lines = registry.personas.map { formatLine(id: $0.id, name: $0.name) }
        case .kits:
            lines = registry.kits.map { formatLine(id: $0.id, name: $0.name) }
        case .tasks:
            lines = registry.tasks.map { formatLine(id: $0.id, name: $0.title) }
        case .intents:
            lines = registry.intentTemplates.map { formatLine(id: $0.id, name: $0.name) }
        case .skills:
            lines = registry.skills.map { formatLine(id: $0.id, name: $0.name) }
        case .essentials:
            lines = try listEssentials(root: root, fileManager: fileManager)
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

    private static func listEssentials(root: URL, fileManager: FileManager) throws -> [String] {
        let essentialsURL = root.appendingPathComponent("Packs/essentials")
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: essentialsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: essentialsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return files
            .filter { $0.pathExtension == "md" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}
