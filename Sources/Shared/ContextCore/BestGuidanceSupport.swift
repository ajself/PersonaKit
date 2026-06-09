import Foundation

/// Builds deterministic agent-facing guidance for PersonaKit scope and grounding decisions.
public enum BestGuidanceSupport {
  /// Structured guidance payload shared by CLI and MCP surfaces.
  public struct Payload: Encodable, Equatable {
    public let schemaVersion: Int
    public let scope: ScopeSummary
    public let counts: Counts
    public let risks: [String]
    public let bestNextActions: [String]
    public let suggestedCommands: [String]
    public let notes: [String]
  }

  /// Scope facts an agent should verify before trusting catalog results.
  public struct ScopeSummary: Encodable, Equatable {
    public let projectRoot: String?
    public let globalRoot: String?
    public let currentDirectoryProjectRoot: String?
    public let loadOrder: [String]
    public let resolutionOrder: [String]
  }

  /// Count summary for loaded and validated PersonaKit context.
  public struct Counts: Encodable, Equatable {
    public let personas: Int
    public let kits: Int
    public let directives: Int
    public let intents: Int
    public let references: Int
    public let skills: Int
    public let essentials: Int
    public let sessions: Int
    public let validationErrors: Int
  }

  /// Builds guidance from already-resolved scopes without changing resolution semantics.
  public static func build(
    scopes: ScopeSet,
    currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) -> Payload {
    let currentDirectoryProjectRoot = ProjectPersonaKitLocator(
      startingURL: URL(fileURLWithPath: currentDirectoryPath)
    )
    .locate()?
    .standardizedFileURL
    .path
    let sessions = loadedSessions(scopes: scopes, fileManager: fileManager)
    let validation = validationResult(scopes: scopes, fileManager: fileManager)
    let counts = Counts(
      personas: validation.result?.counts.personas ?? 0,
      kits: validation.result?.counts.kits ?? 0,
      directives: validation.result?.counts.directives ?? 0,
      intents: validation.result?.counts.intents ?? 0,
      references: validation.result?.counts.references ?? 0,
      skills: validation.result?.counts.skills ?? 0,
      essentials: validation.result?.counts.essentials ?? 0,
      sessions: sessions.value.count,
      validationErrors: validation.result?.errors.count ?? 1
    )
    let risks = riskMessages(
      scopes: scopes,
      currentDirectoryProjectRoot: currentDirectoryProjectRoot,
      homeDirectory: homeDirectory,
      sessionsError: sessions.error,
      validationError: validation.error,
      validationErrors: validation.result?.errors ?? []
    )

    return Payload(
      schemaVersion: 1,
      scope: ScopeSummary(
        projectRoot: scopes.projectScopeURL?.path,
        globalRoot: scopes.globalScopeURL?.path,
        currentDirectoryProjectRoot: currentDirectoryProjectRoot,
        loadOrder: scopes.loadOrder.map(\.path),
        resolutionOrder: scopes.resolutionOrder.map(\.path)
      ),
      counts: counts,
      risks: risks,
      bestNextActions: nextActions(
        risks: risks,
        sessions: sessions.value,
        validationErrors: counts.validationErrors
      ),
      suggestedCommands: suggestedCommands(
        root: preferredCommandRoot(scopes: scopes),
        currentDirectoryProjectRoot: currentDirectoryProjectRoot,
        risks: risks,
        sessions: sessions.value,
        validationErrors: counts.validationErrors
      ),
      notes: [
        "Guidance is advisory and does not select or authorize an operating contract.",
        "Resolve a PersonaKit contract before selecting external skills or acting on a task.",
        "New here? Run `personakit init <path>` for a worked example of every entity, then edit, `personakit validate`, and `personakit export` (or `contract`).",
        "Authoring JSON by hand? Run `personakit schema <entity>` (persona, kit, directive, intent, reference, skill) to see required fields and exact property names.",
      ]
    )
  }

  /// Builds scope-only risk messages without loading sessions or validating packs.
  public static func scopeRiskMessages(
    scopes: ScopeSet,
    currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> [String] {
    let currentDirectoryProjectRoot = ProjectPersonaKitLocator(
      startingURL: URL(fileURLWithPath: currentDirectoryPath)
    )
    .locate()?
    .standardizedFileURL
    .path

    return scopeRiskMessages(
      scopes: scopes,
      currentDirectoryProjectRoot: currentDirectoryProjectRoot,
      homeDirectory: homeDirectory
    )
  }

  /// Encodes guidance payload as stable, pretty-printed JSON.
  public static func encodeJSON(_ payload: Payload) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)

    return String(data: data, encoding: .utf8) ?? "{}"
  }

  private static func loadedSessions(
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> (value: [SessionFile], error: String?) {
    do {
      return (try SessionFileLoader.list(scopes: scopes, fileManager: fileManager), nil)
    } catch {
      return ([], error.localizedDescription)
    }
  }

  private static func validationResult(
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> (result: ValidationResult?, error: String?) {
    do {
      return (try Validator.validate(scopes: scopes, fileManager: fileManager), nil)
    } catch {
      return (nil, error.localizedDescription)
    }
  }

  private static func riskMessages(
    scopes: ScopeSet,
    currentDirectoryProjectRoot: String?,
    homeDirectory: URL,
    sessionsError: String?,
    validationError: String?,
    validationErrors: [ValidationError]
  ) -> [String] {
    var risks = scopeRiskMessages(
      scopes: scopes,
      currentDirectoryProjectRoot: currentDirectoryProjectRoot,
      homeDirectory: homeDirectory
    )

    if let sessionsError {
      risks.append("Session discovery failed: \(sessionsError)")
    }

    if let validationError {
      risks.append("Validation failed before pack checks completed: \(validationError)")
    }

    if !validationErrors.isEmpty {
      risks.append("Validation reported \(validationErrors.count) issue(s) in the loaded scope set.")
    }

    return risks.sorted()
  }

  private static func scopeRiskMessages(
    scopes: ScopeSet,
    currentDirectoryProjectRoot: String?,
    homeDirectory: URL
  ) -> [String] {
    var risks: [String] = []
    let loadedRoots = Set(scopes.resolutionOrder.map { canonicalPath($0) })

    if let currentDirectoryProjectRoot {
      let currentProjectRoot = canonicalPath(URL(fileURLWithPath: currentDirectoryProjectRoot))

      if !loadedRoots.contains(currentProjectRoot) {
        risks.append(
          "Current directory contains a project .personakit that is not in the loaded scope set."
        )
      }
    }

    let homeRoot = canonicalPath(homeDirectory.appendingPathComponent(".personakit"))
    let projectRoot = scopes.projectScopeURL.map { canonicalPath($0) }

    if projectRoot == homeRoot, scopes.globalScopeURL == nil {
      risks.append(
        "MCP or CLI loaded ~/.personakit as the only scope; repo-local sessions may be hidden."
      )
    }

    return risks.sorted()
  }

  private static func nextActions(
    risks: [String],
    sessions: [SessionFile],
    validationErrors: Int
  ) -> [String] {
    if risks.contains(where: { $0.contains("not in the loaded scope set") }) {
      return [
        "Stop and resolve the scope mismatch before selecting a session.",
        "Use an explicit --root that matches the intended project .personakit when repo-local grounding is expected.",
      ]
    }

    if validationErrors > 0 {
      return [
        "Run validation and fix reported PersonaKit issues before resolving a contract."
      ]
    }

    if sessions.isEmpty {
      return [
        "List or create sessions before attempting to resolve a contract."
      ]
    }

    if sessions.count == 1, let session = sessions.first {
      return [
        "Resolve the only available session: \(session.id).",
        "Trace the session if provenance or scope authority needs review.",
      ]
    }

    return [
      "Use recommendation or list sessions to choose the intended session.",
      "Resolve the selected session contract before acting.",
    ]
  }

  private static func suggestedCommands(
    root: URL?,
    currentDirectoryProjectRoot: String?,
    risks: [String],
    sessions: [SessionFile],
    validationErrors: Int
  ) -> [String] {
    if risks.contains(where: { $0.contains("not in the loaded scope set") }) {
      guard let currentDirectoryProjectRoot else {
        return ["personakit guidance"]
      }

      let rootFlag = "--root \(currentDirectoryProjectRoot)"

      return [
        "personakit guidance \(rootFlag)",
        "personakit list \(rootFlag) sessions",
      ]
    }

    guard let root else {
      return ["personakit guidance"]
    }

    let rootFlag = "--root \(root.path)"

    if validationErrors > 0 {
      return ["personakit validate \(rootFlag)"]
    }

    if sessions.count == 1, let session = sessions.first {
      return [
        "personakit contract \(rootFlag) --session \(session.id)",
        "personakit graph \(rootFlag) --session \(session.id)",
      ]
    }

    return [
      "personakit list \(rootFlag) sessions",
      "personakit recommend \(rootFlag) --goal \"<task>\"",
      "personakit contract \(rootFlag) --session <id>",
    ]
  }

  private static func preferredCommandRoot(scopes: ScopeSet) -> URL? {
    scopes.projectScopeURL ?? scopes.globalScopeURL
  }

  private static func canonicalPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }
}
