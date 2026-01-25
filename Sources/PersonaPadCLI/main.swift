import Darwin
import Dependencies
import Foundation
import PersonaPadCore
import PersonaPadResources

enum Command: String {
  case list
  case compose
  case describe
}

struct ParsedArgs {
  var values: [String: String] = [:]
  var flags: Set<String> = []
  var positionals: [String] = []

  func value(for key: String) -> String? {
    values[key]
  }

  func hasFlag(_ key: String) -> Bool {
    flags.contains(key)
  }
}

@main
struct PersonaPadCLI {
  private struct LoadResult {
    let resolved: PersonaResolver.ResolutionResult
    let diagnostics: [Diagnostic]
    let sourcesByID: [String: PersonaSource]
    let packsByID: [String: PackMeta]
  }

  static func main() async {
    let fileClient = CLIEnvironment().fileClient
    let allArgs = Array(CommandLine.arguments.dropFirst())
    guard let (cmd, parsed) = parseCommand(allArgs) else {
      printUsage()
      exit(1)
    }

    let repoRoot = URL(fileURLWithPath: fileClient.currentDirectoryPath())
    let loadResult = loadPersonaData(fileClient: fileClient, repoRoot: repoRoot)

    switch cmd {
    case .list:
      handleList(resolved: loadResult.resolved, diagnostics: loadResult.diagnostics)

    case .compose:
      handleCompose(
        parsed: parsed,
        resolved: loadResult.resolved,
        diagnostics: loadResult.diagnostics
      )

    case .describe:
      handleDescribe(
        parsed: parsed,
        resolved: loadResult.resolved,
        sourcesByID: loadResult.sourcesByID,
        packsByID: loadResult.packsByID,
        repoRoot: repoRoot
      )
    }
  }

  private static func parseCommand(_ allArgs: [String]) -> (Command, ParsedArgs)? {
    guard let first = allArgs.first, let cmd = Command(rawValue: first) else {
      return nil
    }
    let args = Array(allArgs.dropFirst())
    let parsed = parseArgs(args)
    return (cmd, parsed)
  }

  private static func loadPersonaData(fileClient: FileClient, repoRoot: URL) -> LoadResult {
    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []

    let builtIn = loadBuiltInSets(repoRoot: repoRoot)
    sets.append(contentsOf: builtIn.sets)
    diagnostics.append(contentsOf: builtIn.diagnostics)

    let user = loadUserSets(fileClient: fileClient)
    sets.append(contentsOf: user.sets)
    diagnostics.append(contentsOf: user.diagnostics)

    let indexes = buildIndexes(sets: sets)
    let resolved = resolvePersonas(sets: sets, diagnostics: &diagnostics)

    return LoadResult(
      resolved: resolved,
      diagnostics: diagnostics,
      sourcesByID: indexes.sourcesByID,
      packsByID: indexes.packsByID
    )
  }

  private static func loadBuiltInSets(repoRoot: URL) -> (
    sets: [PersonaSet],
    diagnostics: [Diagnostic]
  ) {
    var builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: PersonaPadResources.bundle)
    if builtInURLs.isEmpty {
      builtInURLs = PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }

    guard !builtInURLs.isEmpty else {
      return (
        sets: [],
        diagnostics: [
          .warning(
            source: PersonaSource(kind: .builtIn, url: nil),
            message:
              "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled or run from repo root."
          )
        ]
      )
    }

    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []
    for url in builtInURLs {
      switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
      case .success(let set): sets.append(set)
      case .failure(let error): diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return (sets: sets, diagnostics: diagnostics)
  }

  private static func loadUserSets(fileClient: FileClient) -> (
    sets: [PersonaSet],
    diagnostics: [Diagnostic]
  ) {
    let userPacks = PersonaPadStoragePaths.standard().packs
    guard fileClient.fileExists(userPacks) else {
      return (sets: [], diagnostics: [])
    }
    let loadedUser = UserPackLoader.load(in: userPacks)
    return (sets: loadedUser.packs.map { $0.set }, diagnostics: loadedUser.diagnostics)
  }

  private static func buildIndexes(sets: [PersonaSet]) -> (
    sourcesByID: [String: PersonaSource],
    packsByID: [String: PackMeta]
  ) {
    var sourcesByID: [String: PersonaSource] = [:]
    var packsByID: [String: PackMeta] = [:]

    for set in sets {
      for persona in set.personas {
        sourcesByID[persona.id] = set.source
        packsByID[persona.id] = set.pack
      }
    }

    return (sourcesByID: sourcesByID, packsByID: packsByID)
  }

  private static func resolvePersonas(
    sets: [PersonaSet],
    diagnostics: inout [Diagnostic]
  ) -> PersonaResolver.ResolutionResult {
    let merged = PersonaResolver.mergeSets(sets)
    diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    diagnostics.append(contentsOf: resolved.diagnostics)
    return resolved
  }

  private static func handleList(
    resolved: PersonaResolver.ResolutionResult,
    diagnostics: [Diagnostic]
  ) {
    for key in resolved.personasByID.keys.sorted() {
      if let p = resolved.personasByID[key]?.persona {
        print("\(p.id)\t\(p.name)")
      }
    }
    if !diagnostics.isEmpty {
      printDiagnostics(diagnostics)
    }
  }

  private static func handleCompose(
    parsed: ParsedArgs,
    resolved: PersonaResolver.ResolutionResult,
    diagnostics: [Diagnostic]
  ) {
    let personaID = parsed.value(for: "persona") ?? resolved.personasByID.keys.sorted().first
    guard let id = personaID, let p = resolved.personasByID[id]?.persona else {
      fputs(
        "Persona not found. Fix: run 'personapad list' and use a valid --persona id.\n", stderr)
      exit(2)
    }

    let sections = buildSections(parsed: parsed, persona: p)

    if parsed.hasFlag("resolved-json") {
      if let json = PersonaOutputRenderer.resolvedJSON(persona: p) {
        print(json)
      } else {
        fputs("Failed to encode persona JSON. Fix: ensure the persona data is valid.\n", stderr)
        exit(3)
      }
    } else {
      let prompt = PersonaOutputRenderer.prompt(persona: p, sections: sections)
      print(prompt)
    }

    if !diagnostics.isEmpty {
      printDiagnostics(diagnostics)
    }
  }

  private static func buildSections(parsed: ParsedArgs, persona: Persona) -> [String: String] {
    var sections: [String: String] = [:]
    let sectionKeys =
      (persona.template?.sections?.map { $0.key } ?? [
        "context", "goal", "constraints", "evidence", "task",
      ])
    let wantsStdin =
      (parsed.value(for: "context") == "-") || (parsed.value(for: "evidence") == "-")
    let stdinText = wantsStdin ? readStdinIfAvailable() : nil

    for key in sectionKeys {
      if let v = parsed.value(for: key) {
        if v == "-" {
          sections[key] = stdinText ?? ""
        } else {
          sections[key] = v
        }
      }
    }

    if parsed.value(for: "context") == nil,
      parsed.value(for: "evidence") == nil,
      let piped = readStdinIfAvailable(),
      sectionKeys.contains("context")
    {
      sections["context"] = piped
    }

    return sections
  }

  private static func handleDescribe(
    parsed: ParsedArgs,
    resolved: PersonaResolver.ResolutionResult,
    sourcesByID: [String: PersonaSource],
    packsByID: [String: PackMeta],
    repoRoot: URL
  ) {
    let personaID = parsed.positionals.first ?? parsed.value(for: "persona")
    let result = PersonaDescriptor.describe(
      personaID: personaID,
      resolved: resolved.personasByID,
      sourcesByID: sourcesByID,
      packsByID: packsByID,
      baseURL: repoRoot
    )
    switch result {
    case .success(let text):
      print(text)
    case .failure(let failure):
      fputs("\(failure.message)\n", stderr)
      exit(failure.exitCode)
    }
  }

  static func parseArgs(_ args: [String]) -> ParsedArgs {
    var parsed = ParsedArgs()
    var idx = 0
    while idx < args.count {
      let arg = args[idx]
      if arg.hasPrefix("--") {
        let key = String(arg.dropFirst(2))
        if idx + 1 < args.count, !args[idx + 1].hasPrefix("--") {
          parsed.values[key] = args[idx + 1]
          idx += 2
        } else {
          parsed.flags.insert(key)
          idx += 1
        }
      } else {
        parsed.positionals.append(arg)
        idx += 1
      }
    }
    return parsed
  }

  static func printUsage() {
    print(
      """
      Usage:
        personapad list
        personapad compose --persona <id> [--resolved-json] [--context <text|->] [--goal <text>] [--constraints <text>] [--evidence <text|->] [--task <text>]
        personapad describe <persona-id>

      Notes:
        CLI loads built-ins from the PersonaPadResources bundle (or repo fallback when running from source).
        The macOS app additionally loads user packs from ~/Library/Application Support/PersonaPad/Packs/
      """)
  }
}

private struct CLIEnvironment {
  @Dependency(\.fileClient) var fileClient
}

private func readStdinIfAvailable() -> String? {
  if isatty(STDIN_FILENO) != 0 { return nil }
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard !data.isEmpty else { return nil }
  guard let text = String(data: data, encoding: .utf8) else { return nil }
  return text.trimmingCharacters(in: .newlines)
}

private func printDiagnostics(_ diagnostics: [Diagnostic]) {
  fputs("\nDiagnostics:\n", stderr)
  for d in diagnostics {
    fputs("- [\(d.severity.rawValue)] \(d.userFacingMessage)\n", stderr)
  }
}
