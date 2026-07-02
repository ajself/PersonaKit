import ArgumentParser
import ContextCore
import Foundation

/// Common scope flags shared by multiple CLI commands.
struct ScopeOptions: ParsableArguments {
  @Option(
    name: .customLong("root"),
    help: "Use a specific PersonaKit root.",
    completion: .directory
  )
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

/// Explicit project-root option used by commands that do not allow merged scopes.
struct ExplicitProjectRootOptions: ParsableArguments {
  @Option(
    name: .customLong("root"),
    help: "Project PersonaKit root (.personakit).",
    completion: .directory
  )
  var rootPath: String
}

/// Session selection inputs used by export and graph commands.
struct SessionSelection: ParsableArguments {
  @Option(
    name: .customLong("session"),
    help: "Session id to load.",
    completion: .custom(CLICompletions.sessionIDs)
  )
  var sessionId: String?

  @Option(
    name: .customLong("persona"),
    help: "Persona id to export or graph.",
    completion: .custom(CLICompletions.personaIDs)
  )
  var personaId: String?

  @Option(
    name: .customLong("directive"),
    help: "Directive id to export or graph.",
    completion: .custom(CLICompletions.directiveIDs)
  )
  var directiveId: String?

  @Option(name: .customLong("kits"), help: "Comma-separated kit ids.")
  var kits: String?

  /// Parsed kit IDs from `--kits`.
  var kitIds: [String] {
    Self.parseCSV(kits)
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

    if mode == .contract || mode == .checks,
      directiveId == nil
    {
      guard kitIds.isEmpty else {
        throw ArgumentParser.ValidationError(
          "\(mode.commandName) allows --kits only when --directive is also provided."
        )
      }
      return
    }

    guard directiveId != nil else {
      throw ArgumentParser.ValidationError("\(mode.commandName) requires --directive <id>.")
    }
  }

  /// Parses comma-separated kit IDs into a normalized list.
  static func parseCSV(_ input: String?) -> [String] {
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

enum CLICompletions {
  private struct CompletionScopeSelection {
    var rootPath: String?
    var noProject = false
    var noGlobal = false

    var useProjectScope: Bool {
      !noProject
    }

    var useGlobalScope: Bool {
      !noGlobal
    }
  }

  static func sessionIDs(arguments: [String], index: Int, prefix: String) -> [String] {
    return complete(arguments: arguments, index: index, prefix: prefix) { scopes in
      return try ListCommand.sessionIDs(scopes: scopes)
    }
  }

  static func personaIDs(arguments: [String], index: Int, prefix: String) -> [String] {
    return complete(arguments: arguments, index: index, prefix: prefix) { scopes in
      let registry = try Registry.load(scopes: scopes)
      return registry.personas.map(\.id)
    }
  }

  static func directiveIDs(arguments: [String], index: Int, prefix: String) -> [String] {
    return complete(arguments: arguments, index: index, prefix: prefix) { scopes in
      let registry = try Registry.load(scopes: scopes)
      return registry.directives.map(\.id)
    }
  }

  private static func complete(
    arguments: [String],
    index: Int,
    prefix: String,
    loader: (ScopeSet) throws -> [String]
  ) -> [String] {
    guard let scopes = resolvedScopes(arguments: arguments, index: index),
      let values = try? loader(scopes)
    else {
      return []
    }

    return
      values
      .sorted()
      .filter { prefix.isEmpty || $0.hasPrefix(prefix) }
  }

  private static func resolvedScopes(arguments: [String], index: Int) -> ScopeSet? {
    let options = parsedScopeOptions(arguments: arguments, index: index)

    if let rootPath = normalizedRootPath(options.rootPath) {
      let rootURL = RootPathResolver().resolve(path: rootPath)
      return ScopeSet(projectScopeURL: rootURL, globalScopeURL: nil)
    }

    guard options.useProjectScope || options.useGlobalScope else {
      return nil
    }

    guard let discovered = CLIEnvironment.current.scopeRootResolver.locate() else {
      return nil
    }

    let filtered = ScopeSet(
      projectScopeURL: options.useProjectScope ? discovered.projectScopeURL : nil,
      globalScopeURL: options.useGlobalScope ? discovered.globalScopeURL : nil
    )

    return filtered.isEmpty ? nil : filtered
  }

  private static func normalizedRootPath(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func parsedScopeOptions(arguments: [String], index: Int) -> CompletionScopeSelection {
    var options = CompletionScopeSelection()
    var currentIndex = 0

    while currentIndex < arguments.count {
      if currentIndex == index {
        currentIndex += 1
        continue
      }

      let word = arguments[currentIndex]

      if word == "--root" {
        let nextIndex = currentIndex + 1
        if nextIndex < arguments.count, nextIndex != index {
          options.rootPath = arguments[nextIndex]
        }
        currentIndex += 2
        continue
      }

      if word.hasPrefix("--root=") {
        options.rootPath = String(word.dropFirst("--root=".count))
      } else if word == "--no-project" {
        options.noProject = true
      } else if word == "--no-global" {
        options.noGlobal = true
      }

      currentIndex += 1
    }

    return options
  }
}

/// Command mode used for session selection validation messaging.
enum SessionMode {
  case contract
  case checks
  case export
  case graph
  case resolveReferences

  /// Command name string used in validation errors.
  var commandName: String {
    switch self {
    case .contract:
      return "contract"
    case .checks:
      return "checks"
    case .export:
      return "export"
    case .graph:
      return "graph"
    case .resolveReferences:
      return "resolve-references"
    }
  }
}
