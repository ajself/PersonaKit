import ArgumentParser
import ContextCore
import Foundation

enum SupportedAgent: String, ExpressibleByArgument {
  case opencode

  var providerId: String {
    rawValue
  }
}

struct RunResolution: Equatable {
  let sessionId: String
  let personaId: String
  let directiveId: String
  let kitIds: [String]
  let authorizedSkillIds: [String]
  let authorizedProviderIds: [String]
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
    let authorizedSkillIDs = resolved.skillAuthorization.authorizedSkillIds
    let authorizedSkillIDSet = Set(authorizedSkillIDs)
    let authorizedProviderIDs = Set(
      resolved.skills
        .filter { authorizedSkillIDSet.contains($0.id) }
        .flatMap(\.providedBy)
    )
    .sorted()
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
        kitIds: kitIDs,
        authorizedSkillIds: authorizedSkillIDs,
        authorizedProviderIds: authorizedProviderIDs
      )
    )
  }
}

enum RunAgentAuthorization {
  static func validate(agent: SupportedAgent, resolution: RunResolution) throws {
    guard resolution.authorizedProviderIds.contains(agent.providerId) else {
      let providers = displayList(resolution.authorizedProviderIds)
      let skills = displayList(resolution.authorizedSkillIds)

      throw CLIError.failure(
        [
          "run agent `\(agent.rawValue)` is not authorized by session `\(resolution.sessionId)`.",
          "Add or select an authorized skill whose providedBy includes `\(agent.providerId)`.",
          "Authorized providers: \(providers).",
          "Authorized skills: \(skills).",
        ].joined(separator: " ")
      )
    }
  }

  private static func displayList(_ values: [String]) -> String {
    values.isEmpty ? "none" : values.joined(separator: ", ")
  }
}

struct AgentProcessInvocation: Equatable {
  let executableURL: URL
  let arguments: [String]
}

protocol AgentProcessRunning {
  func run(_ invocation: AgentProcessInvocation) throws -> Int32
}

struct LiveAgentProcessRunner: AgentProcessRunning {
  func run(_ invocation: AgentProcessInvocation) throws -> Int32 {
    let process = Process()
    process.executableURL = invocation.executableURL
    process.arguments = invocation.arguments

    try process.run()
    process.waitUntilExit()

    return process.terminationStatus
  }
}

protocol AgentExecutableResolving {
  func executableURL(named executableName: String) -> URL?
}

struct PathAgentExecutableResolver: AgentExecutableResolving {
  private let fileManager: FileManager
  private let pathValue: String

  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.pathValue = environment["PATH"] ?? ""
  }

  func executableURL(named executableName: String) -> URL? {
    if executableName.contains("/") {
      return executableURL(atPath: executableName)
    }

    for directory in pathValue.split(separator: ":", omittingEmptySubsequences: false) {
      let candidatePath = URL(fileURLWithPath: String(directory), isDirectory: true)
        .appendingPathComponent(executableName)
        .path

      if let executableURL = executableURL(atPath: candidatePath) {
        return executableURL
      }
    }

    return nil
  }

  private func executableURL(atPath path: String) -> URL? {
    guard fileManager.isExecutableFile(atPath: path) else {
      return nil
    }

    return URL(fileURLWithPath: path)
  }
}

struct OpenCodeAgentAdapter {
  private let processRunner: any AgentProcessRunning
  private let executableResolver: any AgentExecutableResolving
  private let temporaryDirectory: URL
  private let fileManager: FileManager

  init(
    processRunner: any AgentProcessRunning = LiveAgentProcessRunner(),
    executableResolver: any AgentExecutableResolving = PathAgentExecutableResolver(),
    temporaryDirectory: URL = FileManager.default.temporaryDirectory,
    fileManager: FileManager = .default
  ) {
    self.processRunner = processRunner
    self.executableResolver = executableResolver
    self.temporaryDirectory = temporaryDirectory
    self.fileManager = fileManager
  }

  func invoke(payload: String) throws -> Int32 {
    guard
      let executableURL = executableResolver.executableURL(
        named: SupportedAgent.opencode.rawValue
      )
    else {
      throw Self.launchFailure()
    }

    let payloadURL =
      temporaryDirectory
      .appendingPathComponent("personakit-run-\(UUID().uuidString)")
      .appendingPathExtension("md")
    try AtomicFileWriter().write(contents: payload, to: payloadURL)
    defer {
      try? fileManager.removeItem(at: payloadURL)
    }

    do {
      return try processRunner.run(
        AgentProcessInvocation(
          executableURL: executableURL,
          arguments: [payloadURL.path]
        )
      )
    } catch {
      throw Self.launchFailure()
    }
  }

  private static func launchFailure() -> CLIError {
    CLIError.failure(
      "Failed to launch opencode. Make sure `opencode` is installed and available on PATH."
    )
  }
}

/// Resolves a session export, wraps it in a runtime payload, and launches one agent.
struct RunCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Preview or launch one supported agent with a resolved session."
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

  @Flag(
    name: .customLong("copy"),
    help: "Copy the dry-run payload to the clipboard instead of printing."
  )
  var copyToClipboard = false

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
    if copyToClipboard, !dryRun {
      throw CLIError.failure("run allows --copy only with --dry-run.")
    }

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
      try RunAgentAuthorization.validate(agent: agent, resolution: result.resolution)

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
        if copyToClipboard {
          guard CLIEnvironment.current.clipboardIO.writeString(result.payload) else {
            throw CLIError.failure("Failed to copy dry-run payload to the clipboard.")
          }

          var stderrStream = StandardError()
          stderrStream.write("Copied dry-run payload to clipboard.\n")
        } else {
          print(result.payload)
        }

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
