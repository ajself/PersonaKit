import Darwin
import Dependencies
import Foundation
import PersonaKitCore
import PersonaKitResources

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
enum PersonaKitCLI {
  private struct LoadResult {
    let resolved: PersonaResolver.ResolutionResult
    let diagnostics: [Diagnostic]
    let sourcesByID: [String: PersonaSource]
    let packsByID: [String: PackMeta]
  }

  static func main() async {
    let fileClient = DependencyValues.current.fileClient
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

    let builtIn = PersonaBuiltInPackLoader.loadBuiltInSets(
      bundle: PersonaKitResources.bundle,
      repoRoot: repoRoot,
      missingResourcesMessage:
        "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled or run from repo root."
    )
    sets.append(contentsOf: builtIn.sets)
    diagnostics.append(contentsOf: builtIn.diagnostics)

    let user = loadUserSets(fileClient: fileClient)
    sets.append(contentsOf: user.sets)
    diagnostics.append(contentsOf: user.diagnostics)

    let indexes = PersonaIndexBuilder.buildIndexes(sets: sets)
    let resolved = resolvePersonas(sets: sets, diagnostics: &diagnostics)

    return LoadResult(
      resolved: resolved,
      diagnostics: diagnostics,
      sourcesByID: indexes.sourcesByID,
      packsByID: indexes.packsByID
    )
  }

  private static func loadUserSets(
    fileClient: FileClient
  ) -> (
    sets: [PersonaSet],
    diagnostics: [Diagnostic]
  ) {
    let userPacks = PersonaKitStoragePaths.standard().packs
    guard fileClient.fileExists(userPacks) else {
      return (sets: [], diagnostics: [])
    }
    let loadedUser = UserPackLoader.load(in: userPacks)
    return (sets: loadedUser.packs.map { $0.set }, diagnostics: loadedUser.diagnostics)
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
      if let persona = resolved.personasByID[key]?.persona {
        print("\(persona.id)\t\(persona.name)")
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
    guard let id = personaID, let persona = resolved.personasByID[id]?.persona else {
      fputs(
        "Persona not found. Fix: run 'personakit list' and use a valid --persona id.\n", stderr)
      exit(2)
    }

    let sections = buildSections(parsed: parsed, persona: persona)

    if parsed.hasFlag("resolved-json") {
      if let json = PersonaOutputRenderer.resolvedJSON(persona: persona) {
        print(json)
      } else {
        fputs("Failed to encode persona JSON. Fix: ensure the persona data is valid.\n", stderr)
        exit(3)
      }
    } else {
      let prompt = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
      print(prompt)
    }

    if !diagnostics.isEmpty {
      printDiagnostics(diagnostics)
    }
  }

  private static func buildSections(parsed: ParsedArgs, persona: Persona) -> [String: String] {
    var sections: [String: String] = [:]
    let sectionKeys =
      persona.template?.sections?.map { $0.key }
      ?? ["context", "goal", "constraints", "evidence", "task"]
    let wantsStdin =
      (parsed.value(for: "context") == "-") || (parsed.value(for: "evidence") == "-")
    let stdinText = wantsStdin ? readStdinIfAvailable() : nil

    for key in sectionKeys {
      if let value = parsed.value(for: key) {
        if value == "-" {
          sections[key] = stdinText ?? ""
        } else {
          sections[key] = value
        }
      }
    }

    let shouldUsePipedContext =
      parsed.value(for: "context") == nil
      && parsed.value(for: "evidence") == nil
      && sectionKeys.contains("context")
    if shouldUsePipedContext, let piped = readStdinIfAvailable() {
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
        personakit list
        personakit compose --persona <id> [--resolved-json] [--context <text|->] [--goal <text>] \
        [--constraints <text>] [--evidence <text|->] [--task <text>]
        personakit describe <persona-id>

      Notes:
        CLI loads built-ins from the PersonaKitResources bundle (or repo fallback when running from source).
        The macOS app additionally loads user packs from ~/Library/Application Support/PersonaKit/Packs/
      """)
  }
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
  for diagnostic in diagnostics {
    fputs("- [\(diagnostic.severity.rawValue)] \(diagnostic.userFacingMessage)\n", stderr)
  }
}
