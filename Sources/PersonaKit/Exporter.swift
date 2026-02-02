import Foundation

enum ExportError: Error {
    case validationFailed(ValidationResult)
    case resolutionFailed(ResolverResolutionError)
    case readFailed(String)
}

struct SessionExporter {
    static func export(
        root: URL,
        personaId: String,
        directiveId: String,
        kitOverrides: [String],
        fileManager: FileManager = .default
    ) throws -> String {
        try export(
            scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
            personaId: personaId,
            directiveId: directiveId,
            kitOverrides: kitOverrides,
            fileManager: fileManager
        )
    }

    static func export(
        scopes: ScopeSet,
        personaId: String,
        directiveId: String,
        kitOverrides: [String],
        fileManager: FileManager = .default
    ) throws -> String {
        let validation = try Validator.validate(scopes: scopes, fileManager: fileManager)
        if !validation.errors.isEmpty {
            throw ExportError.validationFailed(validation)
        }

        let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
        let definition = SessionDefinition(
            personaId: personaId,
            directiveId: directiveId,
            kitOverrides: kitOverrides.isEmpty ? nil : kitOverrides
        )

        let session: ResolvedSession
        do {
            session = try Resolver.resolve(
                definition: definition,
                registry: registry,
                scopes: scopes,
                fileManager: fileManager
            )
        } catch let error as ResolverResolutionError {
            throw ExportError.resolutionFailed(error)
        }

        let essentials = try loadEssentials(session.essentials, fileManager: fileManager)

        return renderSession(
            persona: session.persona,
            directive: session.directive,
            kits: session.kits.sorted { $0.id < $1.id },
            intents: session.intents.sorted { $0.id < $1.id },
            skills: session.skills.sorted { $0.id < $1.id },
            essentials: essentials
        )
    }

    private static func loadEssentials(
        _ essentials: [ResolvedEssential],
        fileManager: FileManager
    ) throws -> [ResolvedEssential] {
        return try essentials.sorted { $0.id < $1.id }.map { essential in
            let data: Data
            do {
                data = try Data(contentsOf: essential.url)
            } catch {
                throw ExportError.readFailed("Failed to read essential: \(essential.id)")
            }
            guard var content = String(data: data, encoding: .utf8) else {
                throw ExportError.readFailed("Failed to decode essential: \(essential.id)")
            }
            if !content.hasSuffix("\n") {
                content.append("\n")
            }
            return ResolvedEssential(id: essential.id, url: essential.url, content: content)
        }
    }

    private static func renderSession(
        persona: Persona,
        directive: Directive,
        kits: [Kit],
        intents: [IntentTemplate],
        skills: [Skill],
        essentials: [ResolvedEssential]
    ) -> String {
        var output = ""

        func appendLine(_ line: String = "") {
            output.append(line)
            output.append("\n")
        }

        appendLine("PersonaKit-Output-Version: 1")
        appendLine()
        appendLine("# Persona")
        appendLine("Name: \(persona.name)")
        appendLine("Id: \(persona.id)")
        if !persona.summary.isEmpty {
            appendLine("Summary: \(persona.summary)")
        }

        appendListSection(title: "Responsibilities", items: persona.responsibilities, appendLine: appendLine)
        appendListSection(title: "Values", items: persona.values, appendLine: appendLine)
        appendListSection(title: "Non-goals", items: persona.nonGoals, appendLine: appendLine)

        let allowedSkills = persona.allowedSkillIds.sorted()
        appendListSection(title: "Allowed Skills", items: allowedSkills, appendLine: appendLine)

        let forbiddenSkills = persona.forbiddenSkillIds.sorted()
        appendListSection(title: "Forbidden Skills", items: forbiddenSkills, appendLine: appendLine)

        appendLine()
        appendLine("# Applied Kits")
        for kit in kits {
            appendLine("- \(kit.name) (\(kit.id))")
        }

        appendLine()
        appendLine("# Essentials")
        for (index, essential) in essentials.enumerated() {
            appendLine("## \(essential.id)")
            output.append(essential.content ?? "")
            if index < essentials.count - 1 {
                appendLine()
            }
        }

        appendLine()
        appendLine("# Directive")
        appendLine("Title: \(directive.title)")
        appendLine("Id: \(directive.id)")
        appendLine("Goal: \(directive.goal)")

        if !directive.steps.isEmpty {
            appendLine()
            appendLine("Steps:")
            for (index, step) in directive.steps.enumerated() {
                var line = "\(index + 1). \(step.text)"
                if step.requiresReview == true {
                    line += " (requires review)"
                }
                appendLine(line)
            }
        }

        appendListSection(title: "Acceptance Criteria", items: directive.acceptanceCriteria, appendLine: appendLine)

        if !directive.verification.isEmpty {
            appendLine()
            appendLine("Verification:")
            for item in directive.verification {
                appendLine("- \(item.kind): \(item.text)")
            }
        }

        let stopPoints = directive.steps.filter { $0.requiresReview == true }.map { $0.text }
        appendListSection(title: "Stop Points", items: stopPoints, appendLine: appendLine)

        appendLine()
        appendLine("# Intent Templates")
        for intent in intents {
            appendLine("## \(intent.id)")
            appendLine("Name: \(intent.name)")
            appendLine("Id: \(intent.id)")
            appendLine("Description: \(intent.description)")

            if !intent.parameters.isEmpty {
                appendLine()
                appendLine("Parameters:")
                for parameter in intent.parameters {
                    let requiredLabel = parameter.required ? "required" : "optional"
                    appendLine("- \(parameter.name) (\(parameter.type), \(requiredLabel))")
                }
            }

            appendLine()
            appendLine("Risk:")
            appendLine("- Level: \(intent.risk.level)")
            appendLine("- Requires human review: \(intent.risk.requiresHumanReview)")
            if !intent.risk.notes.isEmpty {
                appendLine("- Notes:")
                for note in intent.risk.notes {
                    appendLine("  - \(note)")
                }
            }

            let requiredSkills = intent.requiresSkillIds.sorted()
            appendListSection(title: "Required Skills", items: requiredSkills, appendLine: appendLine)

            let includedEssentials = intent.includesEssentialIds.sorted()
            appendListSection(title: "Included Essentials", items: includedEssentials, appendLine: appendLine)

            if intent.id != intents.last?.id {
                appendLine()
            }
        }

        appendLine()
        appendLine("# Skill Awareness")
        for skill in skills {
            appendLine("## \(skill.id)")
            appendLine("Name: \(skill.name)")
            appendLine("Id: \(skill.id)")
            appendLine("Description: \(skill.description)")

            if !skill.providedBy.isEmpty {
                appendLine()
                appendLine("Provided By:")
                for provider in skill.providedBy {
                    appendLine("- \(provider)")
                }
            }

            appendLine()
            appendLine("Risk:")
            appendLine("- Level: \(skill.risk.level)")
            appendLine("- Requires human review: \(skill.risk.requiresHumanReview)")
            if !skill.risk.notes.isEmpty {
                appendLine("- Notes:")
                for note in skill.risk.notes {
                    appendLine("  - \(note)")
                }
            }

            if !skill.notes.isEmpty {
                appendLine()
                appendLine("Notes:")
                for note in skill.notes {
                    appendLine("- \(note)")
                }
            }

            if skill.id != skills.last?.id {
                appendLine()
            }
        }

        return output
    }

    private static func appendListSection(
        title: String,
        items: [String],
        appendLine: (String) -> Void
    ) {
        guard !items.isEmpty else { return }
        appendLine("")
        appendLine("\(title):")
        for item in items {
            appendLine("- \(item)")
        }
    }
}
