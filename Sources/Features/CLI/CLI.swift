import ArgumentParser
import ContextCore
import ContextMCP
import Foundation

/// Runtime wrapper for executing the PersonaKit command tree.
struct PersonaKitCLI {
  private let scopeRootResolver: ScopeRootResolver
  private let mcpServerRunner: any MCPServerRunning
  private let interactiveIO: CLIInteractiveIO
  private let clipboardIO: CLIClipboardIO

  /// Creates a CLI runtime with injectable environment dependencies.
  init(
    scopeRootResolver: ScopeRootResolver = ScopeRootResolver(),
    mcpServerRunner: any MCPServerRunning = MCPServerRunner(),
    interactiveIO: CLIInteractiveIO = .live(),
    clipboardIO: CLIClipboardIO = .live()
  ) {
    self.scopeRootResolver = scopeRootResolver
    self.mcpServerRunner = mcpServerRunner
    self.interactiveIO = interactiveIO
    self.clipboardIO = clipboardIO
  }

  /// Parses and runs PersonaKit command-line arguments.
  ///
  /// - Parameter arguments: Full process argument vector, including executable name.
  /// - Returns: Process exit code (`0` on success).
  func run(arguments: [String]) -> Int32 {
    let context = CLIContext(
      scopeRootResolver: scopeRootResolver,
      mcpServerRunner: mcpServerRunner,
      interactiveIO: interactiveIO,
      clipboardIO: clipboardIO
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
        // Use ArgumentParser's own formatting so parse errors (e.g. an invalid
        // subcommand argument) surface their clear message rather than a generic
        // `localizedDescription`.
        var stderrStream = StandardError()
        stderrStream.write("Error: \(PersonaKitCommand.message(for: error))\n")
        return 1
      }
    }
  }
}

/// Root `personakit` command definition and subcommand registration.
struct PersonaKitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "personakit",
    abstract: "Reusable operating contracts for AI coding work.",
    version: PersonaKitVersion.current,
    subcommands: [
      InitCommand.self,
      CreateCommand.self,
      ValidateCommand.self,
      GuidanceCommand.self,
      RecommendCommand.self,
      ContractCommand.self,
      ChecksCommand.self,
      EnforceCommand.self,
      HookCheckCommand.self,
      ExportCommand.self,
      ResolveGroundingSkillsCommand.self,
      ListCLICommand.self,
      SchemaCLICommand.self,
      GraphCommand.self,
      RefsCommand.self,
      OrphansCommand.self,
      MCPCommand.self,
    ]
  )

  /// Orients a cold agent that runs bare `personakit` with no subcommand.
  ///
  /// Intentionally static and scope-free so it works from any directory, including
  /// outside a `.personakit` root. It points at `guidance` (scope-aware grounding)
  /// and `--help` (the full command surface) rather than resolving scope itself.
  func run() throws {
    print(
      """
      PersonaKit provides reusable operating contracts that ground AI coding agents before they act.

      Run `personakit guidance` to orient against the current scope.
      Run `personakit --help` to see all commands.
      """
    )
  }
}

/// Prints best-effort guidance for agent grounding and scope verification.
struct GuidanceCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "guidance",
    abstract: "Suggest safe PersonaKit grounding steps for the active scope."
  )

  @OptionGroup
  var scope: ScopeOptions

  func run() throws {
    let scopes = try CLIHelpers.resolveMCPScopes(options: scope)
    let payload = BestGuidanceSupport.build(scopes: scopes)
    let output = try BestGuidanceSupport.encodeJSON(payload)

    print(output)
  }
}

/// Initializes a PersonaKit root directory at the provided path.
struct InitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "Initialize a PersonaKit root without replacing non-empty destinations unless --force is set.",
    discussion: """
      Scaffolds a complete, validating worked example of every entity type \
      (persona, kit, directive, skill, essential, session) that you can \
      adapt instead of authoring from scratch. After init: edit the files \
      under Packs/, run `personakit validate`, then `personakit export` (or \
      `personakit contract`) to produce handoff context.
      """
  )

  @Flag(name: .customLong("force"), help: "Replace an existing non-empty destination.")
  var force = false

  @Argument(help: "Destination path.")
  var path: String

  func run() throws {
    try PersonaKitInitializer().run(destination: path, force: force)
    print(
      "Scaffolded a host-neutral personakit-grounding/SKILL.md. "
        + "Per-host variants live under hosts/{claude,copilot,cursor,opencode} "
        + "in the PersonaKit grounding tutorial."
    )
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
    print(scopes.humanSummary)
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
    abstract: "Run the read-only PersonaKit MCP server."
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
