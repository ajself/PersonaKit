import ArgumentParser
import ContextCore
import Foundation

enum SupportedAgent: String, ExpressibleByArgument {
  case opencode
}

struct RunResolution: Equatable {
  let sessionId: String
  let personaId: String
  let directiveId: String
  let kitIds: [String]
}

enum RunPayloadBuilder {
  static func build(
    scopes: ScopeSet,
    session: SessionFile,
    task: String
  ) throws -> (payload: String, resolution: RunResolution) {
    let validation = try Validator.validate(scopes: scopes)

    if !validation.errors.isEmpty {
      throw ExportError.validationFailed(validation)
    }

    let registry = try Registry.load(scopes: scopes)
    let resolved = try Resolver.resolve(
      definition: SessionDefinition(
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: session.kitOverrides
      ),
      registry: registry,
      scopes: scopes
    )
    let exportedContext = try SessionExporter.export(
      scopes: scopes,
      personaId: session.personaId,
      directiveId: session.directiveId,
      kitOverrides: session.kitOverrides ?? [],
      sessionId: session.id
    )
    let kitIDs = resolved.kits.map(\.id).sorted()
    let kitsLine = kitIDs.isEmpty ? "[]" : "[\(kitIDs.joined(separator: ", "))]"
    let payload = """
      # PersonaKit Runtime Payload

      ## Resolution
      - session: \(session.id)
      - persona: \(resolved.persona.id)
      - directive: \(resolved.directive.id)
      - kits: \(kitsLine)

      ## Context
      \(exportedContext)
      ## Task
      \(task)
      """

    return (
      payload: payload,
      resolution: RunResolution(
        sessionId: session.id,
        personaId: resolved.persona.id,
        directiveId: resolved.directive.id,
        kitIds: kitIDs
      )
    )
  }
}

struct OpenCodeAgentAdapter {
  func invoke(payload: String) throws -> Int32 {
    let fileManager = FileManager.default
    let payloadURL = fileManager.temporaryDirectory
      .appendingPathComponent("personakit-run-\(UUID().uuidString)")
      .appendingPathExtension("md")
    try AtomicFileWriter().write(contents: payload, to: payloadURL)
    defer {
      try? fileManager.removeItem(at: payloadURL)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [SupportedAgent.opencode.rawValue, payloadURL.path]

    do {
      try process.run()
    } catch {
      throw CLIError.failure(
        "Failed to launch opencode. Make sure `opencode` is installed and available on PATH."
      )
    }

    process.waitUntilExit()
    return process.terminationStatus
  }
}

/// Resolves a session export, wraps it in a runtime payload, and launches one agent.
struct RunCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Resolve a session and launch a supported agent."
  )

  @OptionGroup
  var scope: ScopeOptions

  @Option(
    name: .customLong("session"),
    help: "Session id to load.",
    completion: .custom(CLICompletions.sessionIDs)
  )
  var sessionId: String

  @Option(name: .customLong("agent"), help: "Agent adapter to invoke.")
  var agent: SupportedAgent

  @Flag(name: .customLong("dry-run"), help: "Print the runtime payload instead of invoking the agent.")
  var dryRun = false

  @Option(name: .customLong("output"), help: "Write the runtime payload to a file path.")
  var outputPath: String?

  @Flag(name: .customLong("verbose"), help: "Print resolution details to stderr.")
  var verbose = false

  @Argument(parsing: .captureForPassthrough, help: "Task text after `--`.")
  var taskFragments: [String] = []

  mutating func validate() throws {
    if normalizedTaskText.isEmpty {
      throw ArgumentParser.ValidationError("run requires a task after `--`.")
    }
  }

  private var normalizedTaskText: String {
    let fragments: [String]

    if taskFragments.first == "--" {
      fragments = Array(taskFragments.dropFirst())
    } else {
      fragments = taskFragments
    }

    return fragments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)

    do {
      let session = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)
      let task = normalizedTaskText

      guard !task.isEmpty else {
        throw ArgumentParser.ValidationError("run requires a task after `--`.")
      }

      let result = try RunPayloadBuilder.build(
        scopes: scopes,
        session: session,
        task: task
      )

      if verbose {
        var stderrStream = StandardError()
        stderrStream.write("Resolved session: \(result.resolution.sessionId)\n")
        stderrStream.write("Resolved persona: \(result.resolution.personaId)\n")
        stderrStream.write("Resolved directive: \(result.resolution.directiveId)\n")
        stderrStream.write("Resolved kits: \(result.resolution.kitIds.joined(separator: ", "))\n")
      }

      if let outputPath {
        let outputURL = RootPathResolver().resolve(path: outputPath)
        try AtomicFileWriter().write(contents: result.payload, to: outputURL)
      }

      if dryRun {
        print(result.payload)
        return
      }

      switch agent {
      case .opencode:
        let exitCode = try OpenCodeAgentAdapter().invoke(payload: result.payload)

        if exitCode != 0 {
          throw ExitCode(exitCode)
        }
      }
    } catch let error as SessionFileError {
      var stderrStream = StandardError()
      stderrStream.write("Error: \(error.localizedDescription)\n")
      throw ExitCode.failure
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
          stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
        }
      case .readFailed(let message):
        stderrStream.write("Error: \(message)\n")
      }
      throw ExitCode.failure
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    }
  }
}
