import Foundation

struct PersonaKitCLI {
    func run(arguments: [String]) -> Int32 {
        var stderrStream = StandardError()
        do {
            try runThrowing(arguments: arguments)
            return 0
        } catch let error as CLIError {
            switch error {
            case .usage(let message):
                stderrStream.write("Error: \(message)\n")
                stderrStream.write("\(usage)\n")
            case .failure(let message):
                stderrStream.write("Error: \(message)\n")
            }
            return 1
        } catch let error as CLIExitError {
            return error.status
        } catch let error as InitError {
            stderrStream.write("Error: \(error.description)\n")
            return 1
        } catch {
            stderrStream.write("Error: \(error.localizedDescription)\n")
            return 1
        }
    }

    private func runThrowing(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            throw CLIError.usage("Missing command.")
        }

        let command = arguments[1]
        switch command {
        case "-h", "--help", "help":
            print(usage)
        case "init":
            guard arguments.count == 3 else {
                throw CLIError.usage("init requires a destination path.")
            }
            try PersonaKitInitializer().run(destination: arguments[2])
        case "validate":
            let options = try ValidateOptionsParser().parse(arguments: Array(arguments.dropFirst(2)))
            let rootURL = RootPathResolver().resolve(path: options.rootPath)
            let result = try Validator.validate(root: rootURL)
            print(result.summary)
            if !result.errors.isEmpty {
                for error in result.errors {
                    print(error.lineDescription())
                }
                throw CLIExitError(status: 1)
            }
        case "export":
            let options = try ExportOptionsParser().parse(arguments: Array(arguments.dropFirst(2)))
            let rootURL = RootPathResolver().resolve(path: options.rootPath)
            do {
                let output = try SessionExporter.export(
                    root: rootURL,
                    personaId: options.personaId,
                    taskId: options.taskId,
                    kitOverrides: options.kitIds
                )
                if let outputPath = options.outputPath {
                    let outputURL = RootPathResolver().resolve(path: outputPath)
                    try AtomicFileWriter().write(contents: output, to: outputURL)
                } else {
                    print(output)
                }
            } catch let error as ExportError {
                var stderrStream = StandardError()
                switch error {
                case .validationFailed(let result):
                    stderrStream.write(result.summary + "\n")
                    for validationError in result.errors {
                        stderrStream.write(validationError.lineDescription() + "\n")
                    }
                case .resolutionFailed(let resolutionError):
                    for resolutionError in resolutionError.errors {
                        stderrStream.write(formatResolutionError(resolutionError) + "\n")
                    }
                case .readFailed(let message):
                    stderrStream.write("Error: \(message)\n")
                }
                throw CLIExitError(status: 1)
            }
        case "list":
            let options = try ListOptionsParser().parse(arguments: Array(arguments.dropFirst(2)))
            let rootURL = RootPathResolver().resolve(path: options.rootPath)
            do {
                let output = try ListCommand.list(root: rootURL, entityType: options.entityType)
                if !output.isEmpty {
                    print(output)
                }
            } catch let error as RegistryLoadError {
                var stderrStream = StandardError()
                for registryError in error.errors {
                    stderrStream.write(formatRegistryError(registryError) + "\n")
                }
                throw CLIExitError(status: 1)
            }
        case "graph":
            let options = try GraphOptionsParser().parse(arguments: Array(arguments.dropFirst(2)))
            let rootURL = RootPathResolver().resolve(path: options.rootPath)
            do {
                let registry = try Registry.load(root: rootURL)
                let definition = SessionDefinition(
                    personaId: options.personaId,
                    taskId: options.taskId,
                    kitOverrides: options.kitIds
                )
                let resolved = try Resolver.resolve(
                    definition: definition,
                    registry: registry,
                    rootURL: rootURL
                )
                let output = GraphPrinter.render(resolvedSession: resolved, kitOverrides: options.kitIds)
                print(output)
            } catch let error as RegistryLoadError {
                var stderrStream = StandardError()
                for registryError in error.errors {
                    stderrStream.write(formatRegistryError(registryError) + "\n")
                }
                throw CLIExitError(status: 1)
            } catch let error as ResolverResolutionError {
                var stderrStream = StandardError()
                for resolutionError in error.errors {
                    stderrStream.write(formatResolutionError(resolutionError) + "\n")
                }
                throw CLIExitError(status: 1)
            }
        default:
            throw CLIError.usage("Unknown command: \(command)")
        }
    }

    private var usage: String {
        return """
        PersonaKit CLI

        Usage:
          personakit init <path>
          personakit validate [--root <path>]
          personakit export --root <path> --persona <id> --task <id> [--kits <id,id,...>] [--output <file>]
          personakit list --root <path> <entityType>
          personakit graph --root <path> --persona <id> --task <id> [--kits <id,id,...>]

        Entity types:
          personas | kits | tasks | intents | skills | essentials
        """
    }

    private func formatResolutionError(_ error: ResolverError) -> String {
        var parts: [String] = [
            error.sourceType.rawValue,
            error.sourceId,
            error.field + ":",
            error.message
        ]
        if case .missingEssentialFile(_, _, _, let missingId, let expectedPath) = error {
            parts.append("missingId=\(missingId)")
            parts.append("expectedPath=\(expectedPath)")
        } else if case .missingKitId(_, _, _, let missingId) = error {
            parts.append("missingId=\(missingId)")
        } else if case .missingIntentId(_, _, _, let missingId) = error {
            parts.append("missingId=\(missingId)")
        } else if case .missingSkillId(_, _, _, let missingId) = error {
            parts.append("missingId=\(missingId)")
        } else if case .missingPersona(_, let missingId) = error {
            parts.append("missingId=\(missingId)")
        } else if case .missingTask(_, let missingId) = error {
            parts.append("missingId=\(missingId)")
        }
        return parts.joined(separator: " ")
    }

    private func formatRegistryError(_ error: RegistryError) -> String {
        var parts: [String] = []
        parts.append(error.entityType.rawValue)
        if let id = error.id {
            parts.append(id)
        }
        if let relativePath = error.relativePath {
            parts.append(relativePath)
        }
        parts.append(error.message)
        return "Error: " + parts.joined(separator: " ")
    }
}

enum CLIError: Error {
    case usage(String)
    case failure(String)
}

struct CLIExitError: Error {
    let status: Int32
}

struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}

struct ExportOptions {
    let rootPath: String
    let personaId: String
    let taskId: String
    let kitIds: [String]
    let outputPath: String?
}

struct ValidateOptions {
    let rootPath: String?
}

struct ListOptions {
    let rootPath: String
    let entityType: ListEntityType
}

struct GraphOptions {
    let rootPath: String
    let personaId: String
    let taskId: String
    let kitIds: [String]
}

struct ExportOptionsParser {
    func parse(arguments: [String]) throws -> ExportOptions {
        var rootPath: String?
        var personaId: String?
        var taskId: String?
        var kitIds: [String] = []
        var outputPath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--root":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--root requires a value.")
                }
                rootPath = arguments[index]
            case "--persona":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--persona requires a value.")
                }
                personaId = arguments[index]
            case "--task":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--task requires a value.")
                }
                taskId = arguments[index]
            case "--kits":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--kits requires a value.")
                }
                kitIds = arguments[index]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            case "--output":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--output requires a value.")
                }
                outputPath = arguments[index]
            default:
                throw CLIError.usage("Unknown export option: \(argument)")
            }
            index += 1
        }

        guard let rootPath else {
            throw CLIError.usage("export requires --root <path>.")
        }
        guard let personaId else {
            throw CLIError.usage("export requires --persona <id>.")
        }
        guard let taskId else {
            throw CLIError.usage("export requires --task <id>.")
        }

        return ExportOptions(
            rootPath: rootPath,
            personaId: personaId,
            taskId: taskId,
            kitIds: kitIds,
            outputPath: outputPath
        )
    }
}

struct ValidateOptionsParser {
    func parse(arguments: [String]) throws -> ValidateOptions {
        var rootPath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--root":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--root requires a value.")
                }
                rootPath = arguments[index]
            default:
                throw CLIError.usage("Unknown validate option: \(argument)")
            }
            index += 1
        }

        return ValidateOptions(rootPath: rootPath)
    }
}

struct ListOptionsParser {
    func parse(arguments: [String]) throws -> ListOptions {
        var rootPath: String?
        var entityType: ListEntityType?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--root":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--root requires a value.")
                }
                rootPath = arguments[index]
            default:
                if argument.hasPrefix("-") {
                    throw CLIError.usage("Unknown list option: \(argument)")
                }
                guard entityType == nil else {
                    throw CLIError.usage("list expects a single entity type.")
                }
                entityType = ListEntityType(rawValue: argument)
                if entityType == nil {
                    throw CLIError.usage("Unknown entity type: \(argument)")
                }
            }
            index += 1
        }

        guard let rootPath else {
            throw CLIError.usage("list requires --root <path>.")
        }
        guard let entityType else {
            throw CLIError.usage("list requires an entity type.")
        }

        return ListOptions(rootPath: rootPath, entityType: entityType)
    }
}

struct GraphOptionsParser {
    func parse(arguments: [String]) throws -> GraphOptions {
        var rootPath: String?
        var personaId: String?
        var taskId: String?
        var kitIds: [String] = []
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--root":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--root requires a value.")
                }
                rootPath = arguments[index]
            case "--persona":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--persona requires a value.")
                }
                personaId = arguments[index]
            case "--task":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--task requires a value.")
                }
                taskId = arguments[index]
            case "--kits":
                index += 1
                guard index < arguments.count else {
                    throw CLIError.usage("--kits requires a value.")
                }
                kitIds = arguments[index]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            default:
                throw CLIError.usage("Unknown graph option: \(argument)")
            }
            index += 1
        }

        guard let rootPath else {
            throw CLIError.usage("graph requires --root <path>.")
        }
        guard let personaId else {
            throw CLIError.usage("graph requires --persona <id>.")
        }
        guard let taskId else {
            throw CLIError.usage("graph requires --task <id>.")
        }

        return GraphOptions(
            rootPath: rootPath,
            personaId: personaId,
            taskId: taskId,
            kitIds: kitIds
        )
    }
}

struct RootPathResolver {
    private let fileManager = FileManager.default

    func resolve(path: String?) -> URL {
        let inputPath = path ?? fileManager.currentDirectoryPath
        let expanded = (inputPath as NSString).expandingTildeInPath
        let absolutePath: String
        if expanded.hasPrefix("/") {
            absolutePath = expanded
        } else {
            absolutePath = (fileManager.currentDirectoryPath as NSString)
                .appendingPathComponent(expanded)
        }
        return URL(fileURLWithPath: absolutePath).standardizedFileURL
    }
}

struct AtomicFileWriter {
    func write(contents: String, to url: URL) throws {
        guard let data = contents.data(using: .utf8) else {
            throw CLIError.failure("Failed to encode export output as UTF-8.")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
