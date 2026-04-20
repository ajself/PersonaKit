import ArgumentParser
import ContextCore
import ContextMCP
import Foundation

/// Request-scoped dependencies shared across CLI command execution.
struct CLIContext: Sendable {
  let scopeRootResolver: ScopeRootResolver
  let mcpServerRunner: any MCPServerRunning
  let interactiveIO: CLIInteractiveIO
  let clipboardIO: CLIClipboardIO

  init(
    scopeRootResolver: ScopeRootResolver,
    mcpServerRunner: any MCPServerRunning,
    interactiveIO: CLIInteractiveIO = .live(),
    clipboardIO: CLIClipboardIO = .live()
  ) {
    self.scopeRootResolver = scopeRootResolver
    self.mcpServerRunner = mcpServerRunner
    self.interactiveIO = interactiveIO
    self.clipboardIO = clipboardIO
  }
}

/// Task-local access to CLI runtime dependencies.
enum CLIEnvironment {
  @TaskLocal
  static var context: CLIContext = CLIContext(
    scopeRootResolver: ScopeRootResolver(),
    mcpServerRunner: MCPServerRunner(),
    interactiveIO: .live(),
    clipboardIO: .live()
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

  /// Resolves and validates an explicit project `.personakit` root.
  static func resolveExplicitProjectRoot(path: String) throws -> URL {
    let rootURL = RootPathResolver().resolve(path: path)
    var isDirectory: ObjCBool = false

    guard
      FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ArgumentParser.ValidationError(
        "--root must point to an existing project .personakit directory: \(rootURL.path)"
      )
    }

    guard rootURL.lastPathComponent == ".personakit" else {
      throw ArgumentParser.ValidationError(
        "--root must point to a project .personakit directory: \(rootURL.path)"
      )
    }

    guard PersonaKitDirectory.hasPacks(root: rootURL) else {
      throw ArgumentParser.ValidationError(
        "--root must contain Packs/: \(rootURL.path)"
      )
    }

    guard PersonaKitDirectory.hasSessions(root: rootURL) else {
      throw ArgumentParser.ValidationError(
        "--root must contain Sessions/: \(rootURL.path)"
      )
    }

    return rootURL
  }

  /// Resolves MCP startup scopes using local-first single-scope selection.
  ///
  /// Resolution order:
  /// 1. `--root`
  /// 2. `PERSONAKIT_ROOT` (and compatibility with `PERSONAKIT_ROOT_OVERRIDE`)
  /// 3. Local project `.personakit`
  /// 4. Global `~/.personakit`
  static func resolveMCPScopes(
    options: ScopeOptions,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> ScopeSet {
    if let rootPath = normalizedRootPath(options.rootPath) {
      let rootURL = RootPathResolver().resolve(path: rootPath)
      return try resolveExplicitMCPRoot(rootURL: rootURL, source: "--root")
    }

    if isTruthy(environment["PERSONAKIT_ROOT_OVERRIDE"]) {
      guard let envRootPath = normalizedRootPath(environment["PERSONAKIT_ROOT"]) else {
        throw ArgumentParser.ValidationError(
          "PERSONAKIT_ROOT_OVERRIDE requires PERSONAKIT_ROOT to be set to a PersonaKit root path."
        )
      }

      let rootURL = RootPathResolver().resolve(path: envRootPath)
      return try resolveExplicitMCPRoot(rootURL: rootURL, source: "PERSONAKIT_ROOT")
    }

    if let envRootPath = normalizedRootPath(environment["PERSONAKIT_ROOT"]) {
      let rootURL = RootPathResolver().resolve(path: envRootPath)
      return try resolveExplicitMCPRoot(rootURL: rootURL, source: "PERSONAKIT_ROOT")
    }

    guard options.useProjectScope || options.useGlobalScope else {
      throw ArgumentParser.ValidationError(
        "No PersonaKit scope found for MCP. Provide --root <path>, set PERSONAKIT_ROOT, or enable project/global discovery."
      )
    }

    if options.useProjectScope {
      let projectLocator = ProjectPersonaKitLocator(
        startingURL: URL(fileURLWithPath: currentDirectoryPath)
      )

      if let projectScopeURL = projectLocator.locate() {
        return ScopeSet(projectScopeURL: projectScopeURL, globalScopeURL: nil)
      }
    }

    if options.useGlobalScope {
      let globalLocator = GlobalPersonaKitLocator(homeDirectory: homeDirectory)

      if let globalScopeURL = globalLocator.locate() {
        return ScopeSet(projectScopeURL: nil, globalScopeURL: globalScopeURL)
      }
    }

    throw ArgumentParser.ValidationError(
      "No PersonaKit scope found for MCP. Provide --root <path>, set PERSONAKIT_ROOT, or create .personakit in this project or ~/.personakit."
    )
  }

  private static func normalizedRootPath(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      return nil
    }

    return trimmed
  }

  private static func resolveExplicitMCPRoot(
    rootURL: URL,
    source: String
  ) throws -> ScopeSet {
    var isDirectory: ObjCBool = false

    guard
      FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ArgumentParser.ValidationError(
        "\(source) root does not exist or is not a directory: \(rootURL.path)"
      )
    }

    guard PersonaKitDirectory.hasPacks(root: rootURL) else {
      throw ArgumentParser.ValidationError(
        "\(source) root must contain Packs/: \(rootURL.path)"
      )
    }

    return ScopeSet(projectScopeURL: rootURL, globalScopeURL: nil)
  }

  private static func isTruthy(_ value: String?) -> Bool {
    guard let value else {
      return false
    }

    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    switch normalized {
    case "1", "true", "yes":
      return true
    default:
      return false
    }
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
    } else if case .missingReferenceId(_, _, _, let missingId) = error {
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
