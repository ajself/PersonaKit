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
            if arguments.count > 2 {
                throw CLIError.usage("validate takes no arguments.")
            }
            throw CLIError.failure("validate is not implemented yet.")
        case "export":
            let options = try ExportOptionsParser().parse(arguments: Array(arguments.dropFirst(2)))
            _ = options
            throw CLIError.failure("export is not implemented yet.")
        case "list":
            if arguments.count > 2 {
                throw CLIError.usage("list takes no arguments.")
            }
            throw CLIError.failure("list is not implemented yet.")
        default:
            throw CLIError.usage("Unknown command: \(command)")
        }
    }

    private var usage: String {
        return """
        PersonaKit CLI

        Usage:
          personakit init <path>
          personakit validate
          personakit export [--persona <id>] [--task <id>]
          personakit list
        """
    }
}

enum CLIError: Error {
    case usage(String)
    case failure(String)
}

struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}

struct ExportOptions {
    let personaId: String?
    let taskId: String?
}

struct ExportOptionsParser {
    func parse(arguments: [String]) throws -> ExportOptions {
        var personaId: String?
        var taskId: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
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
            default:
                throw CLIError.usage("Unknown export option: \(argument)")
            }
            index += 1
        }

        return ExportOptions(personaId: personaId, taskId: taskId)
    }
}
