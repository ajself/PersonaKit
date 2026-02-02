import Foundation

struct PersonaKitInitializer {
    func run(destination: String) throws {
        let destinationURL = try DestinationValidator().validate(path: destination)
        try StarterKitWriter().write(to: destinationURL)
    }
}

struct StarterKitWriter {
    private let fileManager = FileManager.default

    func write(to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for entry in StarterKitManifest.entries {
                let fileURL = destination.appendingPathComponent(entry.relativePath)
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try entry.contents.write(to: fileURL, options: .atomic)
            }
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }
}

struct DestinationValidator {
    private let fileManager = FileManager.default

    func validate(path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw InitError.emptyPath
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let absolutePath: String
        if expanded.hasPrefix("/") {
            absolutePath = expanded
        } else {
            absolutePath = (fileManager.currentDirectoryPath as NSString)
                .appendingPathComponent(expanded)
        }

        let destination = URL(fileURLWithPath: absolutePath).standardizedFileURL
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL

        if destination.path == "/" {
            throw InitError.disallowedPath(destination.path)
        }
        if destination.path == home.path {
            throw InitError.disallowedPath(destination.path)
        }

        return destination
    }
}

enum InitError: Error, Equatable {
    case emptyPath
    case disallowedPath(String)

    var description: String {
        switch self {
        case .emptyPath:
            return "Destination path is required."
        case .disallowedPath(let path):
            return "Refusing to initialize at unsafe destination: \(path)"
        }
    }
}

struct StarterFile: Equatable {
    let relativePath: String
    let contents: Data
}

enum StarterKitManifest {
    static let entries: [StarterFile] = [
        StarterFile(
            relativePath: "Packs/personas/senior-swiftui-engineer.persona.json",
            contents: "{\n  \"id\": \"senior-swiftui-engineer\",\n  \"version\": \"1.0\",\n  \"name\": \"Senior SwiftUI Engineer\",\n  \"summary\": \"Pragmatic, accessibility-first, small diffs.\",\n  \"responsibilities\": [\n    \"Implement SwiftUI features\",\n    \"Maintain accessibility\",\n    \"Write tests for changes\"\n  ],\n  \"values\": [\n    \"correctness over cleverness\",\n    \"small diffs\",\n    \"clarity\"\n  ],\n  \"nonGoals\": [\n    \"architecture rewrites\",\n    \"introducing new frameworks without approval\"\n  ],\n  \"defaultKitIds\": [\n    \"swift-style\",\n    \"swiftui-style\",\n    \"repo-constraints\"\n  ],\n  \"allowedSkillIds\": [\n    \"codex-cli\"\n  ],\n  \"forbiddenSkillIds\": [\n    \"autonomous-agent-loop\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/kits/swift-style.kit.json",
            contents: "{\n  \"id\": \"swift-style\",\n  \"version\": \"1.0\",\n  \"name\": \"Swift Style Kit\",\n  \"summary\": \"Swift language style and conventions.\",\n  \"essentialIds\": [\n    \"swift-style-guide\",\n    \"tools-and-constraints\",\n    \"non-goals\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/kits/swiftui-style.kit.json",
            contents: "{\n  \"id\": \"swiftui-style\",\n  \"version\": \"1.0\",\n  \"name\": \"SwiftUI Style Kit\",\n  \"summary\": \"SwiftUI-specific style and accessibility rules.\",\n  \"essentialIds\": [\n    \"swiftui-style-guide\",\n    \"tools-and-constraints\",\n    \"non-goals\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/kits/repo-constraints.kit.json",
            contents: "{\n  \"id\": \"repo-constraints\",\n  \"version\": \"1.0\",\n  \"name\": \"Repository Constraints Kit\",\n  \"summary\": \"Rules specific to this codebase.\",\n  \"essentialIds\": [\n    \"environment\",\n    \"tools-and-constraints\",\n    \"non-goals\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/tasks/apply-style.task.json",
            contents: "{\n  \"id\": \"apply-style\",\n  \"version\": \"1.0\",\n  \"title\": \"Apply Swift + SwiftUI style guides\",\n  \"goal\": \"Ensure the change matches Swift and SwiftUI style guides.\",\n  \"steps\": [\n    {\n      \"text\": \"Identify the target files and intended behavior.\"\n    },\n    {\n      \"text\": \"Apply Swift and SwiftUI style rules consistently.\"\n    },\n    {\n      \"text\": \"Avoid unrelated refactors.\",\n      \"requiresReview\": true\n    },\n    {\n      \"text\": \"Update or add tests as needed.\"\n    },\n    {\n      \"text\": \"Provide a concise diff summary.\"\n    }\n  ],\n  \"acceptanceCriteria\": [\n    \"Code matches Swift style guide\",\n    \"Code matches SwiftUI style guide\",\n    \"Tests pass\",\n    \"No unintended behavior changes\"\n  ],\n  \"verification\": [\n    {\n      \"kind\": \"command\",\n      \"text\": \"swift test\"\n    },\n    {\n      \"kind\": \"manual\",\n      \"text\": \"Review diff for scope creep\"\n    }\n  ],\n  \"requiresIntentTemplateIds\": [\n    \"swift-refactor-safe\"\n  ],\n  \"requiresSkillIds\": [\n    \"codex-cli\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/intents/swift-refactor-safe.intent.json",
            contents: "{\n  \"id\": \"swift-refactor-safe\",\n  \"version\": \"1.0\",\n  \"name\": \"Swift Refactor (Safe)\",\n  \"description\": \"Perform a small refactor without changing behavior.\",\n  \"parameters\": [\n    {\n      \"name\": \"targetFiles\",\n      \"type\": \"string[]\",\n      \"required\": true\n    }\n  ],\n  \"includesEssentialIds\": [\n    \"swift-style-guide\",\n    \"tools-and-constraints\",\n    \"non-goals\"\n  ],\n  \"requiresSkillIds\": [\n    \"codex-cli\"\n  ],\n  \"risk\": {\n    \"level\": \"medium\",\n    \"requiresHumanReview\": true,\n    \"notes\": [\n      \"No public API changes\",\n      \"No behavior changes\"\n    ]\n  }\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/skills/autonomous-agent-loop.skill.json",
            contents: "{\n  \"id\": \"autonomous-agent-loop\",\n  \"version\": \"1.0\",\n  \"name\": \"Autonomous Agent Loop\",\n  \"description\": \"Executes tasks without human checkpoints.\",\n  \"providedBy\": [\n    \"autonomous-agent-loop\"\n  ],\n  \"risk\": {\n    \"level\": \"high\",\n    \"requiresHumanReview\": true,\n    \"notes\": [\n      \"Execution is not allowed in PersonaKit\"\n    ]\n  },\n  \"notes\": [\n    \"Forbidden by default.\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/skills/codex-cli.skill.json",
            contents: "{\n  \"id\": \"codex-cli\",\n  \"version\": \"1.0\",\n  \"name\": \"Codex CLI\",\n  \"description\": \"Edits files and produces PR-sized diffs (outside PersonaKit).\",\n  \"providedBy\": [\n    \"codex-cli\"\n  ],\n  \"risk\": {\n    \"level\": \"medium\",\n    \"requiresHumanReview\": false,\n    \"notes\": []\n  },\n  \"notes\": [\n    \"PersonaKit never executes tools.\"\n  ]\n}".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/essentials/environment.md",
            contents: "# Environment\n\n- Platform: macOS\n- Language: Swift\n".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/essentials/swift-style-guide.md",
            contents: "# Swift Style Guide\n\n(Paste your real Swift style guide here.)\n".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/essentials/swiftui-style-guide.md",
            contents: "# SwiftUI Style Guide\n\n(Paste your real SwiftUI style guide here.)\n".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/essentials/tools-and-constraints.md",
            contents: "# Tools & Constraints\n\n- No large refactors\n- No new dependencies without approval\n".utf8Data
        ),
        StarterFile(
            relativePath: "Packs/essentials/non-goals.md",
            contents: "# Non-Goals\n\n- No architecture rewrites\n- No execution inside PersonaKit\n".utf8Data
        )
    ]
}

private extension String {
    var utf8Data: Data {
        Data(self.utf8)
    }
}
