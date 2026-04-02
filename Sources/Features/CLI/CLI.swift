import ArgumentParser
import ContextCore
import ContextMCP
import Foundation

/// Runtime wrapper for executing the PersonaKit command tree.
struct PersonaKitCLI {
  private let scopeRootResolver: ScopeRootResolver
  private let mcpServerRunner: any MCPServerRunning
  private let interactiveIO: CLIInteractiveIO

  /// Creates a CLI runtime with injectable environment dependencies.
  init(
    scopeRootResolver: ScopeRootResolver = ScopeRootResolver(),
    mcpServerRunner: any MCPServerRunning = MCPServerRunner(),
    interactiveIO: CLIInteractiveIO = .live()
  ) {
    self.scopeRootResolver = scopeRootResolver
    self.mcpServerRunner = mcpServerRunner
    self.interactiveIO = interactiveIO
  }

  /// Parses and runs PersonaKit command-line arguments.
  ///
  /// - Parameter arguments: Full process argument vector, including executable name.
  /// - Returns: Process exit code (`0` on success).
  func run(arguments: [String]) -> Int32 {
    let context = CLIContext(
      scopeRootResolver: scopeRootResolver,
      mcpServerRunner: mcpServerRunner,
      interactiveIO: interactiveIO
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
      } catch let exitCode as ExitCode {
        return exitCode.rawValue
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
      CreateCommand.self,
      ValidateCommand.self,
      WorkstreamDocsCommand.self,
      MigrateLogRecordsCommand.self,
      LogDocsCommand.self,
      ContractCommand.self,
      ExportCommand.self,
      ResolveReferencesCommand.self,
      ListCLICommand.self,
      GraphCommand.self,
      MCPCommand.self,
      RunCommand.self,
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

/// Starts the PersonaKit MCP server process.
struct MCPCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mcp",
    abstract: "Run the PersonaKit MCP server."
  )

  @OptionGroup
  var scope: ScopeOptions

  func run() throws {
    let scopes = try CLIHelpers.resolveMCPScopes(options: scope)
    try CLIEnvironment.current.mcpServerRunner.run(
      version: PersonaKitVersion.current,
      scopes: scopes
    )
  }
}
