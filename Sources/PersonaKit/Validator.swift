import Foundation

enum ValidationEntityType: String {
    case persona
    case kit
    case task
    case intent
    case skill
    case essentials

    var sortOrder: Int {
        switch self {
        case .persona: return 1
        case .kit: return 2
        case .task: return 3
        case .intent: return 4
        case .skill: return 5
        case .essentials: return 6
        }
    }
}

struct ValidationError: Error, Equatable {
    let entityType: ValidationEntityType
    let entityId: String?
    let field: String
    let missingId: String?
    let expectedPath: String?
    let message: String

    func lineDescription() -> String {
        var parts: [String] = [entityType.rawValue]
        if let entityId {
            parts.append(entityId)
        }
        parts.append(field + ":")
        parts.append(message)
        if let missingId {
            parts.append("missingId=\(missingId)")
        }
        if let expectedPath {
            parts.append("expectedPath=\(expectedPath)")
        }
        return parts.joined(separator: " ")
    }
}

struct ValidationCounts: Equatable {
    let personas: Int
    let kits: Int
    let tasks: Int
    let intents: Int
    let skills: Int
    let essentials: Int

    static let zero = ValidationCounts(
        personas: 0,
        kits: 0,
        tasks: 0,
        intents: 0,
        skills: 0,
        essentials: 0
    )
}

struct ValidationResult: Equatable {
    let counts: ValidationCounts
    let errors: [ValidationError]

    var summary: String {
        return "Validation summary: personas=\(counts.personas) kits=\(counts.kits) tasks=\(counts.tasks) intents=\(counts.intents) skills=\(counts.skills) essentials=\(counts.essentials) errors=\(errors.count)"
    }

    init(counts: ValidationCounts, errors: [ValidationError]) {
        self.counts = counts
        self.errors = ValidationResult.sort(errors: errors)
    }

    private static func sort(errors: [ValidationError]) -> [ValidationError] {
        return errors.sorted { lhs, rhs in
            if lhs.entityType.sortOrder != rhs.entityType.sortOrder {
                return lhs.entityType.sortOrder < rhs.entityType.sortOrder
            }
            let lhsId = lhs.entityId ?? ""
            let rhsId = rhs.entityId ?? ""
            if lhsId != rhsId {
                return lhsId < rhsId
            }
            if lhs.field != rhs.field {
                return lhs.field < rhs.field
            }
            let lhsMissing = lhs.missingId ?? ""
            let rhsMissing = rhs.missingId ?? ""
            if lhsMissing != rhsMissing {
                return lhsMissing < rhsMissing
            }
            let lhsPath = lhs.expectedPath ?? ""
            let rhsPath = rhs.expectedPath ?? ""
            if lhsPath != rhsPath {
                return lhsPath < rhsPath
            }
            return lhs.message < rhs.message
        }
    }
}

struct Validator {
    static func validate(root: URL, fileManager: FileManager = .default) throws -> ValidationResult {
        let registry: Registry
        do {
            registry = try Registry.load(root: root, fileManager: fileManager)
        } catch let error as RegistryLoadError {
            let errors = error.errors.map { registryError in
                ValidationError(
                    entityType: map(entityType: registryError.entityType),
                    entityId: registryError.id,
                    field: registryError.id == nil ? "file" : "id",
                    missingId: nil,
                    expectedPath: registryError.relativePath,
                    message: registryError.message
                )
            }
            return ValidationResult(counts: .zero, errors: errors)
        }

        let essentialsDirectory = root.appendingPathComponent("Packs/essentials")
        var errors: [ValidationError] = []

        for persona in registry.personas {
            for kitId in persona.defaultKitIds {
                if registry.kitsById[kitId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .persona,
                            entityId: persona.id,
                            field: "defaultKitIds",
                            missingId: kitId,
                            expectedPath: nil,
                            message: "Missing kit id \"\(kitId)\"."
                        )
                    )
                }
            }

            for skillId in persona.allowedSkillIds {
                if registry.skillsById[skillId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .persona,
                            entityId: persona.id,
                            field: "allowedSkillIds",
                            missingId: skillId,
                            expectedPath: nil,
                            message: "Missing skill id \"\(skillId)\"."
                        )
                    )
                }
            }

            for skillId in persona.forbiddenSkillIds {
                if registry.skillsById[skillId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .persona,
                            entityId: persona.id,
                            field: "forbiddenSkillIds",
                            missingId: skillId,
                            expectedPath: nil,
                            message: "Missing skill id \"\(skillId)\"."
                        )
                    )
                }
            }
        }

        for kit in registry.kits {
            for intentId in kit.intentTemplateIds ?? [] {
                if registry.intentTemplatesById[intentId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .kit,
                            entityId: kit.id,
                            field: "intentTemplateIds",
                            missingId: intentId,
                            expectedPath: nil,
                            message: "Missing intent template id \"\(intentId)\"."
                        )
                    )
                }
            }

            for skillId in kit.skillIds ?? [] {
                if registry.skillsById[skillId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .kit,
                            entityId: kit.id,
                            field: "skillIds",
                            missingId: skillId,
                            expectedPath: nil,
                            message: "Missing skill id \"\(skillId)\"."
                        )
                    )
                }
            }

            for essentialId in kit.essentialIds {
                let expectedPath = "Packs/essentials/\(essentialId).md"
                let fileURL = root.appendingPathComponent(expectedPath)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    errors.append(
                        ValidationError(
                            entityType: .kit,
                            entityId: kit.id,
                            field: "essentialIds",
                            missingId: essentialId,
                            expectedPath: expectedPath,
                            message: "Missing essential file at \(expectedPath)."
                        )
                    )
                }
            }
        }

        for task in registry.tasks {
            for intentId in task.requiresIntentTemplateIds {
                if registry.intentTemplatesById[intentId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .task,
                            entityId: task.id,
                            field: "requiresIntentTemplateIds",
                            missingId: intentId,
                            expectedPath: nil,
                            message: "Missing intent template id \"\(intentId)\"."
                        )
                    )
                }
            }

            for skillId in task.requiresSkillIds {
                if registry.skillsById[skillId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .task,
                            entityId: task.id,
                            field: "requiresSkillIds",
                            missingId: skillId,
                            expectedPath: nil,
                            message: "Missing skill id \"\(skillId)\"."
                        )
                    )
                }
            }
        }

        for intent in registry.intentTemplates {
            for essentialId in intent.includesEssentialIds {
                let expectedPath = "Packs/essentials/\(essentialId).md"
                let fileURL = root.appendingPathComponent(expectedPath)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    errors.append(
                        ValidationError(
                            entityType: .intent,
                            entityId: intent.id,
                            field: "includesEssentialIds",
                            missingId: essentialId,
                            expectedPath: expectedPath,
                            message: "Missing essential file at \(expectedPath)."
                        )
                    )
                }
            }

            for skillId in intent.requiresSkillIds {
                if registry.skillsById[skillId] == nil {
                    errors.append(
                        ValidationError(
                            entityType: .intent,
                            entityId: intent.id,
                            field: "requiresSkillIds",
                            missingId: skillId,
                            expectedPath: nil,
                            message: "Missing skill id \"\(skillId)\"."
                        )
                    )
                }
            }
        }

        let counts = ValidationCounts(
            personas: registry.personasById.count,
            kits: registry.kitsById.count,
            tasks: registry.tasksById.count,
            intents: registry.intentTemplatesById.count,
            skills: registry.skillsById.count,
            essentials: countEssentialFiles(at: essentialsDirectory, fileManager: fileManager)
        )

        return ValidationResult(counts: counts, errors: errors)
    }

    private static func map(entityType: RegistryEntityType) -> ValidationEntityType {
        switch entityType {
        case .persona: return .persona
        case .kit: return .kit
        case .task: return .task
        case .intentTemplate: return .intent
        case .skill: return .skill
        case .packsRoot: return .essentials
        }
    }

    private static func countEssentialFiles(at directory: URL, fileManager: FileManager) -> Int {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return 0
        }
        do {
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return files.filter { $0.lastPathComponent.hasSuffix(".md") }.count
        } catch {
            return 0
        }
    }
}
