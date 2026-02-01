import Foundation

enum RegistryEntityType: String {
    case packsRoot = "packs"
    case persona
    case kit
    case task
    case intentTemplate
    case skill

    var sortOrder: Int {
        switch self {
        case .packsRoot: return 0
        case .persona: return 1
        case .kit: return 2
        case .task: return 3
        case .intentTemplate: return 4
        case .skill: return 5
        }
    }
}

struct RegistryError: Error, Equatable {
    let relativePath: String?
    let entityType: RegistryEntityType
    let id: String?
    let message: String
}

struct RegistryLoadError: Error, Equatable {
    let errors: [RegistryError]

    init(errors: [RegistryError]) {
        self.errors = RegistryLoadError.sort(errors: errors)
    }

    private static func sort(errors: [RegistryError]) -> [RegistryError] {
        return errors.sorted { lhs, rhs in
            if lhs.entityType.sortOrder != rhs.entityType.sortOrder {
                return lhs.entityType.sortOrder < rhs.entityType.sortOrder
            }
            let lhsId = lhs.id ?? ""
            let rhsId = rhs.id ?? ""
            if lhsId != rhsId {
                return lhsId < rhsId
            }
            let lhsPath = lhs.relativePath ?? ""
            let rhsPath = rhs.relativePath ?? ""
            if lhsPath != rhsPath {
                return lhsPath < rhsPath
            }
            return lhs.message < rhs.message
        }
    }
}

struct Registry {
    let personasById: [String: Persona]
    let kitsById: [String: Kit]
    let tasksById: [String: Task]
    let intentTemplatesById: [String: IntentTemplate]
    let skillsById: [String: Skill]

    var personas: [Persona] {
        personasById.sorted { $0.key < $1.key }.map { $0.value }
    }

    var kits: [Kit] {
        kitsById.sorted { $0.key < $1.key }.map { $0.value }
    }

    var tasks: [Task] {
        tasksById.sorted { $0.key < $1.key }.map { $0.value }
    }

    var intentTemplates: [IntentTemplate] {
        intentTemplatesById.sorted { $0.key < $1.key }.map { $0.value }
    }

    var skills: [Skill] {
        skillsById.sorted { $0.key < $1.key }.map { $0.value }
    }

    static func load(root: URL, fileManager: FileManager = .default) throws -> Registry {
        try load(scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil), fileManager: fileManager)
    }

    static func load(scopes: ScopeSet, fileManager: FileManager = .default) throws -> Registry {
        let roots = scopes.loadOrder
        guard !roots.isEmpty else {
            let error = RegistryError(
                relativePath: "Packs",
                entityType: .packsRoot,
                id: nil,
                message: "Missing Packs directory."
            )
            throw RegistryLoadError(errors: [error])
        }

        var errors: [RegistryError] = []
        let decoder = JSONDecoder()
        var personasById: [String: Persona] = [:]
        var kitsById: [String: Kit] = [:]
        var tasksById: [String: Task] = [:]
        var intentTemplatesById: [String: IntentTemplate] = [:]
        var skillsById: [String: Skill] = [:]

        for root in roots {
            let packsURL = PersonaKitDirectory.packsURL(root: root)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: packsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                errors.append(
                    RegistryError(
                        relativePath: "Packs",
                        entityType: .packsRoot,
                        id: nil,
                        message: "Missing Packs directory."
                    )
                )
                continue
            }

            let personas: [String: Persona] = loadEntities(
                root: root,
                directory: packsURL.appendingPathComponent("personas"),
                suffix: ".persona.json",
                entityType: .persona,
                decoder: decoder,
                fileManager: fileManager,
                errors: &errors
            )

            let kits: [String: Kit] = loadEntities(
                root: root,
                directory: packsURL.appendingPathComponent("kits"),
                suffix: ".kit.json",
                entityType: .kit,
                decoder: decoder,
                fileManager: fileManager,
                errors: &errors
            )

            let tasks: [String: Task] = loadEntities(
                root: root,
                directory: packsURL.appendingPathComponent("tasks"),
                suffix: ".task.json",
                entityType: .task,
                decoder: decoder,
                fileManager: fileManager,
                errors: &errors
            )

            let intents: [String: IntentTemplate] = loadEntities(
                root: root,
                directory: packsURL.appendingPathComponent("intents"),
                suffix: ".intent.json",
                entityType: .intentTemplate,
                decoder: decoder,
                fileManager: fileManager,
                errors: &errors
            )

            let skills: [String: Skill] = loadEntities(
                root: root,
                directory: packsURL.appendingPathComponent("skills"),
                suffix: ".skill.json",
                entityType: .skill,
                decoder: decoder,
                fileManager: fileManager,
                errors: &errors
            )

            for (id, persona) in personas {
                personasById[id] = persona
            }
            for (id, kit) in kits {
                kitsById[id] = kit
            }
            for (id, task) in tasks {
                tasksById[id] = task
            }
            for (id, intent) in intents {
                intentTemplatesById[id] = intent
            }
            for (id, skill) in skills {
                skillsById[id] = skill
            }
        }

        if !errors.isEmpty {
            throw RegistryLoadError(errors: errors)
        }

        return Registry(
            personasById: personasById,
            kitsById: kitsById,
            tasksById: tasksById,
            intentTemplatesById: intentTemplatesById,
            skillsById: skillsById
        )
    }
}

private protocol EntityWithID {
    var id: String { get }
}

extension Persona: EntityWithID {}
extension Kit: EntityWithID {}
extension Task: EntityWithID {}
extension IntentTemplate: EntityWithID {}
extension Skill: EntityWithID {}

private func loadEntities<T: Decodable & EntityWithID>(
    root: URL,
    directory: URL,
    suffix: String,
    entityType: RegistryEntityType,
    decoder: JSONDecoder,
    fileManager: FileManager,
    errors: inout [RegistryError]
) -> [String: T] {
    var results: [String: T] = [:]
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        return results
    }

    let files: [URL]
    do {
        files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        let relativePath = relativePath(for: directory, root: root)
        errors.append(
            RegistryError(
                relativePath: relativePath,
                entityType: entityType,
                id: nil,
                message: "Failed to read directory: \(error.localizedDescription)"
            )
        )
        return results
    }

    let sortedFiles = files
        .filter { $0.lastPathComponent.hasSuffix(suffix) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for fileURL in sortedFiles {
        let relativePath = relativePath(for: fileURL, root: root)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            errors.append(
                RegistryError(
                    relativePath: relativePath,
                    entityType: entityType,
                    id: nil,
                    message: "Failed to read file: \(error.localizedDescription)"
                )
            )
            continue
        }

        let decoded: T
        do {
            decoded = try decoder.decode(T.self, from: data)
        } catch {
            errors.append(
                RegistryError(
                    relativePath: relativePath,
                    entityType: entityType,
                    id: nil,
                    message: "Failed to decode JSON: \(error.localizedDescription)"
                )
            )
            continue
        }

        if results[decoded.id] != nil {
            errors.append(
                RegistryError(
                    relativePath: relativePath,
                    entityType: entityType,
                    id: decoded.id,
                    message: "Duplicate id \"\(decoded.id)\"."
                )
            )
            continue
        }

        results[decoded.id] = decoded
    }

    return results
}

private func relativePath(for fileURL: URL, root: URL) -> String {
    let rootComponents = root.standardizedFileURL.pathComponents
    let fileComponents = fileURL.standardizedFileURL.pathComponents
    let relativeComponents = fileComponents.dropFirst(rootComponents.count)
    return relativeComponents.joined(separator: "/")
}
