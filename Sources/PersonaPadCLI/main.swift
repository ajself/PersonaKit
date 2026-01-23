import Foundation
import Darwin
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
  static func main() async {
    let allArgs = Array(CommandLine.arguments.dropFirst())
    guard let first = allArgs.first, let cmd = Command(rawValue: first) else {
      printUsage()
      exit(1)
    }
    let args = Array(allArgs.dropFirst())
    let parsed = parseArgs(args)

    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: PersonaPadResources.bundle)
    if builtInURLs.isEmpty {
      builtInURLs = PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }

    var sets: [PersonaSet] = []
    var diags: [Diagnostic] = []
    var sourcesByID: [String: PersonaSource] = [:]
    var packsByID: [String: PackMeta] = [:]

    if builtInURLs.isEmpty {
      diags.append(.warning(
        source: PersonaSource(kind: .builtIn, url: nil),
        message: "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled or run from repo root."
      ))
    } else {
      for url in builtInURLs {
        switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
        case .success(let set): sets.append(set)
        case .failure(let error): diags.append(contentsOf: error.diagnostics)
        }
      }
    }

    // User packs dir
    let userPacks = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/PersonaPad/Packs", isDirectory: true)
    if FileManager.default.fileExists(atPath: userPacks.path) {
      let loadedUser = PersonaLoader.loadDocuments(in: userPacks, sourceKind: .user)
      sets.append(contentsOf: loadedUser.sets)
      diags.append(contentsOf: loadedUser.diagnostics)
    }

    for set in sets {
      for persona in set.personas {
        sourcesByID[persona.id] = set.source
        packsByID[persona.id] = set.pack
      }
    }

    let merged = PersonaResolver.mergeSets(sets)
    diags.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    diags.append(contentsOf: resolved.diagnostics)

    switch cmd {
    case .list:
      for key in resolved.personasByID.keys.sorted() {
        if let p = resolved.personasByID[key]?.persona {
          print("\(p.id)\t\(p.name)")
        }
      }
      if !diags.isEmpty {
        printDiagnostics(diags)
      }

    case .compose:
      // Very simple flag parsing
      let personaID = parsed.value(for: "persona") ?? resolved.personasByID.keys.sorted().first
      guard let id = personaID, let p = resolved.personasByID[id]?.persona else {
        fputs("Persona not found. Fix: run 'personapad list' and use a valid --persona id.\n", stderr)
        exit(2)
      }

      var sections: [String: String] = [:]
      let sectionKeys = (p.template?.sections?.map { $0.key } ?? ["context", "goal", "constraints", "evidence", "task"])
      let wantsStdin = (parsed.value(for: "context") == "-") || (parsed.value(for: "evidence") == "-")
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
         sectionKeys.contains("context") {
        sections["context"] = piped
      }

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

      if !diags.isEmpty {
        printDiagnostics(diags)
      }

    case .describe:
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
    print("""
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
