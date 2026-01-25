import Foundation

extension BuildCompareCLI {
  /// Prints usage help text to stdout.
  static func printUsage() {
    let text = """
      Usage:
        Scripts/build-compare <baseSha> <headSha> [options]

      Options:
        --out <path>            Output directory (default: /tmp/personakit-build-compare/<timestamp>)
        --worktree-root <path>  Worktree root (default: <out>/worktrees)
        --workspace <name>      Xcode workspace (default: auto-detect)
        --scheme <name>         Xcode scheme (default: PersonaKitApp)
        --configuration <name>  Build configuration (default: Release)
        --config <path>         JSON config file for app build recipes (default: Scripts/build-compare.json if present)
        --allow-test-failures   Record test failures without aborting the run
        --no-tests              Skip swift test
        --no-incremental        Skip incremental builds
        --keep-worktrees        Keep worktrees after run
        -h, --help              Show help
      """
    print(text)
  }

  /// Parses command-line arguments into strongly typed options.
  static func parseArgs() throws -> Options {
    var parser = ArgumentParser(args: CommandLine.arguments.dropFirst())
    return try parser.parse()
  }
}

private enum ValueOption: String {
  case out = "--out"
  case worktreeRoot = "--worktree-root"
  case scheme = "--scheme"
  case workspace = "--workspace"
  case configuration = "--configuration"
  case config = "--config"
}

private enum FlagOption: String {
  case helpShort = "-h"
  case help = "--help"
  case allowTestFailures = "--allow-test-failures"
  case keepWorktrees = "--keep-worktrees"
  case noTests = "--no-tests"
  case noIncremental = "--no-incremental"
}

private struct ArgumentParser {
  private var args: ArraySlice<String>
  private var baseSha: String?
  private var headSha: String?
  private var outputRoot: URL?
  private var worktreeRoot: URL?
  private var workspace: String?
  private var scheme = "PersonaKitApp"
  private var schemeIsDefault = true
  private var configuration = "Release"
  private var configPath: String?
  private var allowTestFailures = false
  private var keepWorktrees = false
  private var runTests = true
  private var runIncremental = true

  init(args: ArraySlice<String>) {
    self.args = args
  }

  mutating func parse() throws -> Options {
    discardDoubleDash()
    while let arg = pop() {
      try handle(arg)
    }
    return try finalize()
  }

  private mutating func handle(_ arg: String) throws {
    if let option = ValueOption(rawValue: arg) {
      let value = try requireValue(for: arg)
      apply(option, value: value)
      return
    }
    if let option = FlagOption(rawValue: arg) {
      apply(option)
      return
    }
    try assignPositional(arg)
  }

  private mutating func discardDoubleDash() {
    if args.first == "--" {
      _ = pop()
    }
  }

  private mutating func apply(_ option: ValueOption, value: String) {
    switch option {
    case .out:
      outputRoot = URL(fileURLWithPath: value)
    case .worktreeRoot:
      worktreeRoot = URL(fileURLWithPath: value)
    case .scheme:
      scheme = value
      schemeIsDefault = false
    case .workspace:
      workspace = value
    case .configuration:
      configuration = value
    case .config:
      configPath = value
    }
  }

  private mutating func apply(_ option: FlagOption) {
    switch option {
    case .helpShort, .help:
      BuildCompareCLI.printUsage()
      exit(0)
    case .allowTestFailures:
      allowTestFailures = true
    case .keepWorktrees:
      keepWorktrees = true
    case .noTests:
      runTests = false
    case .noIncremental:
      runIncremental = false
    }
  }

  private mutating func assignPositional(_ value: String) throws {
    if baseSha == nil {
      baseSha = value
    } else if headSha == nil {
      headSha = value
    } else {
      throw ToolError.usage("Unexpected argument: \(value)")
    }
  }

  private mutating func finalize() throws -> Options {
    guard let base = baseSha, let head = headSha else {
      throw ToolError.usage("Missing required SHAs.\n")
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let safeTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
    let defaultOut = URL(fileURLWithPath: "/tmp/personakit-build-compare/\(safeTimestamp)")
    let out = outputRoot ?? defaultOut
    let worktrees = worktreeRoot ?? out.appendingPathComponent("worktrees")

    return Options(
      baseSha: base,
      headSha: head,
      outputRoot: out,
      worktreeRoot: worktrees,
      workspace: workspace,
      scheme: scheme,
      schemeIsDefault: schemeIsDefault,
      configuration: configuration,
      configPath: configPath,
      allowTestFailures: allowTestFailures,
      keepWorktrees: keepWorktrees,
      runTests: runTests,
      runIncremental: runIncremental
    )
  }

  private mutating func pop() -> String? {
    guard let first = args.first else { return nil }
    args = args.dropFirst()
    return first
  }

  private mutating func requireValue(for option: String) throws -> String {
    guard let value = pop() else {
      throw ToolError.usage("Missing value for \(option)")
    }
    return value
  }
}
