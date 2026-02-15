import ArgumentParser
import ContextCore
import ContextMCP
import Foundation

/// Runtime wrapper for executing the PersonaKit command tree.
struct PersonaKitCLI {
  private let scopeRootResolver: ScopeRootResolver
  private let mcpServerRunner: any MCPServerRunning

  /// Creates a CLI runtime with injectable environment dependencies.
  init(
    scopeRootResolver: ScopeRootResolver = ScopeRootResolver(),
    mcpServerRunner: any MCPServerRunning = MCPServerRunner()
  ) {
    self.scopeRootResolver = scopeRootResolver
    self.mcpServerRunner = mcpServerRunner
  }

  /// Parses and runs PersonaKit command-line arguments.
  ///
  /// - Parameter arguments: Full process argument vector, including executable name.
  /// - Returns: Process exit code (`0` on success).
  func run(arguments: [String]) -> Int32 {
    let context = CLIContext(
      scopeRootResolver: scopeRootResolver,
      mcpServerRunner: mcpServerRunner
    )

    return CLIEnvironment.withContext(context) {
      do {
        var command = try PersonaKitCommand.parseAsRoot(Array(arguments.dropFirst()))
        try command.run()
        return 0
      } catch is CleanExit {
        return 0
      } catch let error as ArgumentParser.ValidationError {
        var stderrStream = StandardError()
        stderrStream.write("Error: \(error.message)\n")
        return 1
      } catch is ExitCode {
        return 1
      } catch {
        var stderrStream = StandardError()
        stderrStream.write("Error: \(error.localizedDescription)\n")
        return 1
      }
    }
  }
}

/// Root `personakit` command definition and subcommand registration.
struct PersonaKitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "personakit",
    abstract: "PersonaKit CLI",
    subcommands: [
      InitCommand.self,
      ValidateCommand.self,
      ExportCommand.self,
      ListCLICommand.self,
      GraphCommand.self,
      MCPCommand.self,
    ]
  )
}

/// Initializes a PersonaKit root directory at the provided path.
struct InitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "Initialize a PersonaKit root."
  )

  @Argument(help: "Destination path.")
  var path: String

  func run() throws {
    try PersonaKitInitializer().run(destination: path)
  }
}

/// Validates PersonaKit packs across resolved scopes.
struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate PersonaKit packs."
  )

  @OptionGroup
  var scope: ScopeOptions

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    let result = try Validator.validate(scopes: scopes)
    print(result.summary)
    if !result.errors.isEmpty {
      for error in result.errors {
        print(error.lineDescription())
      }
      throw ExitCode.failure
    }
  }
}

/// Exports a resolved PersonaKit session as text.
struct ExportCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "export",
    abstract: "Export a session prompt."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @Option(name: .customLong("output"), help: "Write output to a file path.")
  var outputPath: String?

  mutating func validate() throws {
    try session.validate(mode: .export)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    do {
      let sessionInput = try CLIHelpers.resolveSessionInput(
        from: session,
        scopes: scopes
      )
      let output = try SessionExporter.export(
        scopes: scopes,
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides
      )
      if let outputPath {
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
          stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
        }
      case .readFailed(let message):
        stderrStream.write("Error: \(message)\n")
      }
      throw ExitCode.failure
    }
  }
}

/// Lists PersonaKit entities for resolved scopes.
struct ListCLICommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List entities from loaded scopes."
  )

  @OptionGroup
  var scope: ScopeOptions

  @Argument(help: "Entity type to list.")
  var entityType: ListEntityType

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    do {
      let output = try ListCommand.list(scopes: scopes, entityType: entityType)
      if !output.isEmpty {
        print(output)
      }
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    }
  }
}

/// Renders a resolved PersonaKit session graph.
struct GraphCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "graph",
    abstract: "Render a session graph."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  mutating func validate() throws {
    try session.validate(mode: .graph)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    do {
      let sessionInput = try CLIHelpers.resolveSessionInput(
        from: session,
        scopes: scopes
      )
      let registry = try Registry.load(scopes: scopes)
      let definition = SessionDefinition(
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides.isEmpty ? nil : sessionInput.kitOverrides
      )
      let resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
      let output = GraphPrinter.render(
        resolvedSession: resolved,
        kitOverrides: sessionInput.kitOverrides
      )
      print(output)
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

/// Starts the PersonaKit MCP server process.
struct MCPCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mcp",
    abstract: "Run the PersonaKit MCP server."
  )

  func run() throws {
    try CLIEnvironment.current.mcpServerRunner.run(version: PersonaKitVersion.current)
  }
}

/// Common scope flags shared by multiple CLI commands.
struct ScopeOptions: ParsableArguments {
  @Option(name: .customLong("root"), help: "Use a specific PersonaKit root.")
  var rootPath: String?

  @Flag(name: .customLong("no-project"), help: "Disable project scope discovery.")
  var noProject = false

  @Flag(name: .customLong("no-global"), help: "Disable global scope discovery.")
  var noGlobal = false

  /// Indicates whether project scope discovery is enabled.
  var useProjectScope: Bool {
    !noProject
  }

  /// Indicates whether global scope discovery is enabled.
  var useGlobalScope: Bool {
    !noGlobal
  }
}

/// Session selection inputs used by export and graph commands.
struct SessionSelection: ParsableArguments {
  @Option(name: .customLong("session"), help: "Session id to load.")
  var sessionId: String?

  @Option(name: .customLong("persona"), help: "Persona id to export or graph.")
  var personaId: String?

  @Option(name: .customLong("directive"), help: "Directive id to export or graph.")
  var directiveId: String?

  @Option(name: .customLong("kits"), help: "Comma-separated kit ids.")
  var kits: String?

  /// Parsed kit IDs from `--kits`.
  var kitIds: [String] {
    Self.parseKitIds(kits)
  }

  /// Validates flag combinations for the target command mode.
  func validate(mode: SessionMode) throws {
    if sessionId != nil {
      if personaId != nil || directiveId != nil || !kitIds.isEmpty {
        throw ArgumentParser.ValidationError(
          "\(mode.commandName) requires --session or --persona/--directive, not both."
        )
      }
      return
    }

    guard personaId != nil else {
      throw ArgumentParser.ValidationError("\(mode.commandName) requires --persona <id>.")
    }
    guard directiveId != nil else {
      throw ArgumentParser.ValidationError("\(mode.commandName) requires --directive <id>.")
    }
  }

  /// Parses comma-separated kit IDs into a normalized list.
  private static func parseKitIds(_ input: String?) -> [String] {
    guard let input else {
      return []
    }
    return
      input
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

/// Command mode used for session selection validation messaging.
enum SessionMode {
  case export
  case graph

  /// Command name string used in validation errors.
  var commandName: String {
    switch self {
    case .export:
      return "export"
    case .graph:
      return "graph"
    }
  }
}

/// Request-scoped dependencies shared across CLI command execution.
struct CLIContext: Sendable {
  let scopeRootResolver: ScopeRootResolver
  let mcpServerRunner: any MCPServerRunning
}

/// Task-local access to CLI runtime dependencies.
enum CLIEnvironment {
  @TaskLocal
  static var context: CLIContext = CLIContext(
    scopeRootResolver: ScopeRootResolver(),
    mcpServerRunner: MCPServerRunner()
  )

  /// The currently active CLI context.
  static var current: CLIContext {
    context
  }

  /// Executes work with an overridden task-local context.
  static func withContext<T>(_ context: CLIContext, _ body: () throws -> T) rethrows -> T {
    try $context.withValue(context) {
      try body()
    }
  }
}

/// Shared helper logic used by multiple CLI commands.
enum CLIHelpers {
  /// Resolves session input from either `--session` or explicit selector flags.
  static func resolveSessionInput(
    from options: SessionSelection,
    scopes: ScopeSet
  ) throws -> SessionInput {
    if let sessionId = options.sessionId {
      let session = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)
      let overrides = session.kitOverrides ?? []
      return SessionInput(
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: overrides
      )
    }

    guard let personaId = options.personaId, let directiveId = options.directiveId else {
      throw ArgumentParser.ValidationError("Missing session input.")
    }
    return SessionInput(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: options.kitIds
    )
  }

  /// Resolves scope roots from explicit flags or environment discovery.
  static func resolveScopes(options: ScopeOptions) throws -> ScopeSet {
    if let rootPath = options.rootPath {
      let rootURL = RootPathResolver().resolve(path: rootPath)
      return ScopeSet(projectScopeURL: rootURL, globalScopeURL: nil)
    }

    guard options.useProjectScope || options.useGlobalScope else {
      throw ArgumentParser.ValidationError(
        "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
      )
    }
    guard let discovered = CLIEnvironment.current.scopeRootResolver.locate() else {
      throw ArgumentParser.ValidationError(
        "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
      )
    }

    let filtered = ScopeSet(
      projectScopeURL: options.useProjectScope ? discovered.projectScopeURL : nil,
      globalScopeURL: options.useGlobalScope ? discovered.globalScopeURL : nil
    )
    guard !filtered.isEmpty else {
      throw ArgumentParser.ValidationError(
        "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
      )
    }

    return filtered
  }

  /// Formats a resolution error for stable CLI output.
  static func formatResolutionError(_ error: ResolverError) -> String {
    var parts: [String] = [
      error.sourceType.rawValue,
      error.sourceId,
      error.field + ":",
      error.message,
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
    } else if case .missingDirective(_, let missingId) = error {
      parts.append("missingId=\(missingId)")
    }
    return parts.joined(separator: " ")
  }

  /// Formats a registry load error for CLI stderr output.
  static func formatRegistryError(_ error: RegistryError) -> String {
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

/// CLI-specific error type for user-facing failures.
enum CLIError: LocalizedError {
  case failure(String)

  /// User-facing error description.
  var errorDescription: String? {
    switch self {
    case .failure(let message):
      return message
    }
  }
}

/// `stderr` text stream used by ArgumentParser command implementations.
struct StandardError: TextOutputStream {
  mutating func write(_ string: String) {
    guard let data = string.data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
  }
}

/// Normalized resolved session identifiers used by export and graph commands.
struct SessionInput {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

/// Resolves CLI path inputs into standardized absolute URLs.
struct RootPathResolver {
  private let fileManager = FileManager.default

  /// Expands and resolves an optional path.
  ///
  /// - Parameter path: Optional path input; defaults to current directory.
  /// - Returns: Standardized absolute file URL.
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

/// Writes UTF-8 files atomically, creating parent directories as needed.
struct AtomicFileWriter {
  /// Writes string content to disk using UTF-8 encoding and atomic replacement.
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
