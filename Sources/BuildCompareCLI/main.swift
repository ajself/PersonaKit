import BuildCompareCore
import Foundation

struct CommandResult {
  let exitCode: Int32
  let output: String
  let duration: TimeInterval
}

enum ToolError: Error, CustomStringConvertible {
  case usage(String)
  case commandFailed(String)
  case notFound(String)

  var description: String {
    switch self {
    case let .usage(message):
      return message
    case let .commandFailed(message):
      return message
    case let .notFound(message):
      return message
    }
  }
}

struct Options {
  let baseSha: String
  let headSha: String
  let outputRoot: URL
  let worktreeRoot: URL
  let workspace: String?
  let scheme: String
  let schemeIsDefault: Bool
  let configuration: String
  let configPath: String?
  let allowTestFailures: Bool
  let keepWorktrees: Bool
  let runTests: Bool
  let runIncremental: Bool
}

func printUsage() {
  let text = """
  Usage:
    Scripts/build-compare <base_sha> <head_sha> [options]

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

func parseArgs() throws -> Options {
  var args = CommandLine.arguments.dropFirst()
  var baseSha: String?
  var headSha: String?
  var outputRoot: URL?
  var worktreeRoot: URL?
  var workspace: String?
  var scheme = "PersonaKitApp"
  var schemeIsDefault = true
  var configuration = "Release"
  var configPath: String?
  var allowTestFailures = false
  var keepWorktrees = false
  var runTests = true
  var runIncremental = true

  func pop() -> String? {
    guard let first = args.first else { return nil }
    args = args.dropFirst()
    return first
  }

  if args.first == "--" {
    _ = pop()
  }

  while let arg = pop() {
    switch arg {
    case "-h", "--help":
      printUsage()
      exit(0)
    case "--out":
      guard let value = pop() else { throw ToolError.usage("Missing value for --out") }
      outputRoot = URL(fileURLWithPath: value)
    case "--worktree-root":
      guard let value = pop() else { throw ToolError.usage("Missing value for --worktree-root") }
      worktreeRoot = URL(fileURLWithPath: value)
    case "--scheme":
      guard let value = pop() else { throw ToolError.usage("Missing value for --scheme") }
      scheme = value
      schemeIsDefault = false
    case "--workspace":
      guard let value = pop() else { throw ToolError.usage("Missing value for --workspace") }
      workspace = value
    case "--configuration":
      guard let value = pop() else { throw ToolError.usage("Missing value for --configuration") }
      configuration = value
    case "--config":
      guard let value = pop() else { throw ToolError.usage("Missing value for --config") }
      configPath = value
    case "--allow-test-failures":
      allowTestFailures = true
    case "--keep-worktrees":
      keepWorktrees = true
    case "--no-tests":
      runTests = false
    case "--no-incremental":
      runIncremental = false
    default:
      if baseSha == nil {
        baseSha = arg
      } else if headSha == nil {
        headSha = arg
      } else {
        throw ToolError.usage("Unexpected argument: \(arg)")
      }
    }
  }

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

func runTool(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> CommandResult {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = [tool] + args
  process.currentDirectoryURL = cwd
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = pipe
  let start = Date()
  try process.run()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  let end = Date()
  let output = String(data: data, encoding: .utf8) ?? ""
  return CommandResult(exitCode: process.terminationStatus, output: output, duration: end.timeIntervalSince(start))
}

func directorySize(at url: URL) -> Int64 {
  let fm = FileManager.default
  guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
    return 0
  }
  var total: Int64 = 0
  for case let fileURL as URL in enumerator {
    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
       let size = values.fileSize {
      total += Int64(size)
    }
  }
  return total
}

func fileSize(at url: URL) -> Int64 {
  let fm = FileManager.default
  guard let attrs = try? fm.attributesOfItem(atPath: url.path),
        let size = attrs[.size] as? NSNumber else {
    return 0
  }
  return size.int64Value
}

func ensureDirectory(_ url: URL) throws {
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
}

func writeLog(_ text: String, to url: URL) throws {
  try text.write(to: url, atomically: true, encoding: .utf8)
}

func repoRoot() throws -> URL {
  let result = try runTool("git", ["rev-parse", "--show-toplevel"])
  if result.exitCode != 0 {
    throw ToolError.commandFailed("git rev-parse failed:\n\(result.output)")
  }
  let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
  if path.isEmpty {
    throw ToolError.notFound("Could not determine repo root.")
  }
  return URL(fileURLWithPath: path)
}

func versionInfo() throws -> (swift: String, xcode: String) {
  let swiftResult = try runTool("swift", ["--version"])
  let xcodeResult = try runTool("xcodebuild", ["-version"])
  return (swiftResult.output.trimmingCharacters(in: .whitespacesAndNewlines),
          xcodeResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
}

func addWorktree(repo: URL, path: URL, sha: String) throws {
  let result = try runTool("git", ["worktree", "add", path.path, sha], cwd: repo)
  if result.exitCode != 0 {
    throw ToolError.commandFailed("git worktree add failed:\n\(result.output)")
  }
}

func removeWorktree(repo: URL, path: URL) throws {
  let result = try runTool("git", ["worktree", "remove", path.path], cwd: repo)
  if result.exitCode != 0 {
    throw ToolError.commandFailed("git worktree remove failed:\n\(result.output)")
  }
}

func detectWorkspace(in repo: URL, override: String?) throws -> String {
  if let override {
    return override
  }
  let fm = FileManager.default
  let preferred = ["PersonaKit.xcworkspace", "PersonaPad.xcworkspace"]
  for name in preferred {
    let path = repo.appendingPathComponent(name)
    if fm.fileExists(atPath: path.path) {
      return name
    }
  }

  let contents = try fm.contentsOfDirectory(atPath: repo.path)
  if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
    return workspace
  }

  throw ToolError.notFound("No .xcworkspace found in \(repo.path). Use --workspace to override.")
}

func resolveScheme(defaultScheme: String, schemeIsDefault: Bool, workspace: String) -> String {
  guard schemeIsDefault else { return defaultScheme }
  if workspace == "PersonaPad.xcworkspace", defaultScheme == "PersonaKitApp" {
    return "PersonaPadApp"
  }
  return defaultScheme
}

func defaultAppRecipes() -> [AppBuildRecipe] {
  [
    AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuild_args: []),
    AppBuildRecipe(
      name: "legacy-driver",
      workspace: nil,
      scheme: nil,
      xcodebuild_args: ["SWIFT_USE_INTEGRATED_DRIVER=NO"]
    ),
    AppBuildRecipe(
      name: "legacy-explicit-modules-off",
      workspace: nil,
      scheme: nil,
      xcodebuild_args: ["SWIFT_ENABLE_EXPLICIT_MODULES=NO"]
    ),
    AppBuildRecipe(
      name: "legacy-build-system",
      workspace: nil,
      scheme: nil,
      xcodebuild_args: ["-UseNewBuildSystem=NO"]
    ),
    AppBuildRecipe(
      name: "legacy-build-system-driver",
      workspace: nil,
      scheme: nil,
      xcodebuild_args: ["-UseNewBuildSystem=NO", "SWIFT_USE_INTEGRATED_DRIVER=NO"]
    )
  ]
}

func loadConfig(repo: URL, overridePath: String?) throws -> BuildCompareConfig? {
  let fm = FileManager.default
  let configURL: URL?
  if let overridePath {
    configURL = URL(fileURLWithPath: overridePath)
  } else {
    let defaultPath = repo.appendingPathComponent("Scripts/build-compare.json")
    configURL = fm.fileExists(atPath: defaultPath.path) ? defaultPath : nil
  }

  guard let url = configURL else { return nil }
  let data = try Data(contentsOf: url)
  let decoder = JSONDecoder()
  return try decoder.decode(BuildCompareConfig.self, from: data)
}

func buildApp(
  repo: URL,
  workspace: String,
  scheme: String,
  configuration: String,
  derivedData: URL,
  logDir: URL,
  runIncremental: Bool,
  extraArgs: [String],
  recipeName: String
) throws -> (BuildStepMetrics, BuildStepMetrics?, BinaryMetric?) {
  let fm = FileManager.default
  if fm.fileExists(atPath: derivedData.path) {
    try? fm.removeItem(at: derivedData)
  }
  try ensureDirectory(logDir)

  let cleanLog = logDir.appendingPathComponent("app-clean-\(recipeName).log")
  let baseArgs = [
    "-workspace", workspace,
    "-scheme", scheme,
    "-configuration", configuration,
    "-derivedDataPath", derivedData.path,
    "CODE_SIGNING_ALLOWED=NO",
    "-showBuildTimingSummary"
  ]
  let buildArgs = baseArgs + extraArgs + ["build"]
  let cleanResult = try runTool("xcodebuild", buildArgs, cwd: repo)
  try writeLog(cleanResult.output, to: cleanLog)
  if cleanResult.exitCode != 0 {
    throw ToolError.commandFailed("App clean build failed. Log: \(cleanLog.path)\n\(cleanResult.output)")
  }
  let cleanWarnings = countWarnings(cleanResult.output)
  let cleanTiming = parseTimingSummary(cleanResult.output)
  let cleanMetrics = BuildStepMetrics(
    duration_seconds: cleanResult.duration,
    warnings_count: cleanWarnings,
    timing_summary: cleanTiming.isEmpty ? nil : cleanTiming,
    log_path: cleanLog.path,
    output_path: derivedData.path
  )

  var incrementalMetrics: BuildStepMetrics?
  if runIncremental {
    let incrLog = logDir.appendingPathComponent("app-incremental-\(recipeName).log")
    let incrResult = try runTool("xcodebuild", buildArgs, cwd: repo)
    try writeLog(incrResult.output, to: incrLog)
    if incrResult.exitCode != 0 {
      throw ToolError.commandFailed("App incremental build failed. Log: \(incrLog.path)\n\(incrResult.output)")
    }
    let incrWarnings = countWarnings(incrResult.output)
    let incrTiming = parseTimingSummary(incrResult.output)
    incrementalMetrics = BuildStepMetrics(
      duration_seconds: incrResult.duration,
      warnings_count: incrWarnings,
      timing_summary: incrTiming.isEmpty ? nil : incrTiming,
      log_path: incrLog.path,
      output_path: derivedData.path
    )
  }

  let products = derivedData.appendingPathComponent("Build/Products/\(configuration)")
  let appURL = products.appendingPathComponent("\(scheme).app")
  let exeURL = products.appendingPathComponent(scheme)
  var binaryMetric: BinaryMetric?
  if fm.fileExists(atPath: appURL.path) {
    let size = directorySize(at: appURL)
    binaryMetric = BinaryMetric(path: appURL.path, size_bytes: size)
  } else if fm.fileExists(atPath: exeURL.path) {
    let size = fileSize(at: exeURL)
    binaryMetric = BinaryMetric(path: exeURL.path, size_bytes: size)
  }

  return (cleanMetrics, incrementalMetrics, binaryMetric)
}

func buildCli(
  repo: URL,
  configuration: String,
  logDir: URL,
  runIncremental: Bool
) throws -> (BuildStepMetrics, BuildStepMetrics?, [BinaryMetric]) {
  let fm = FileManager.default
  try ensureDirectory(logDir)
  let buildDir = repo.appendingPathComponent(".build")
  if fm.fileExists(atPath: buildDir.path) {
    _ = try? runTool("swift", ["package", "clean"], cwd: repo)
  }

  let cleanLog = logDir.appendingPathComponent("cli-clean.log")
  let cleanResult = try runTool("swift", ["build", "-c", configuration.lowercased()], cwd: repo)
  try writeLog(cleanResult.output, to: cleanLog)
  if cleanResult.exitCode != 0 {
    throw ToolError.commandFailed("CLI clean build failed. Log: \(cleanLog.path)\n\(cleanResult.output)")
  }
  let cleanMetrics = BuildStepMetrics(
    duration_seconds: cleanResult.duration,
    warnings_count: countWarnings(cleanResult.output),
    timing_summary: nil,
    log_path: cleanLog.path,
    output_path: buildDir.path
  )

  var incrementalMetrics: BuildStepMetrics?
  if runIncremental {
    let incrLog = logDir.appendingPathComponent("cli-incremental.log")
    let incrResult = try runTool("swift", ["build", "-c", configuration.lowercased()], cwd: repo)
    try writeLog(incrResult.output, to: incrLog)
    if incrResult.exitCode != 0 {
      throw ToolError.commandFailed("CLI incremental build failed. Log: \(incrLog.path)\n\(incrResult.output)")
    }
    incrementalMetrics = BuildStepMetrics(
      duration_seconds: incrResult.duration,
      warnings_count: countWarnings(incrResult.output),
      timing_summary: nil,
      log_path: incrLog.path,
      output_path: buildDir.path
    )
  }

  let releaseDir = repo.appendingPathComponent(".build/release")
  let binariesToCheck = ["personakit", "personakit-validate"]
  var binaries: [BinaryMetric] = []
  for name in binariesToCheck {
    let path = releaseDir.appendingPathComponent(name)
    if fm.fileExists(atPath: path.path) {
      binaries.append(BinaryMetric(path: path.path, size_bytes: fileSize(at: path)))
    }
  }

  return (cleanMetrics, incrementalMetrics, binaries)
}

func runTests(
  repo: URL,
  configuration: String,
  logDir: URL,
  allowFailures: Bool
) throws -> TestMetrics {
  try ensureDirectory(logDir)
  let log = logDir.appendingPathComponent("tests.log")
  let result = try runTool("swift", ["test", "-c", configuration.lowercased()], cwd: repo)
  try writeLog(result.output, to: log)
  let warnings = countWarnings(result.output)
  let success = result.exitCode == 0
  if !success, !allowFailures {
    throw ToolError.commandFailed("Tests failed. Log: \(log.path)\n\(result.output)")
  }
  return TestMetrics(duration_seconds: result.duration, warnings_count: warnings, success: success, log_path: log.path)
}

func runForRevision(
  label: String,
  sha: String,
  repo: URL,
  workspace: String,
  scheme: String,
  recipes: [AppBuildRecipe],
  configuration: String,
  outputRoot: URL,
  runTestsFlag: Bool,
  allowTestFailures: Bool,
  runIncrementalFlag: Bool
) throws -> RevisionMetrics {
  let logDir = outputRoot.appendingPathComponent("logs/\(label)")
  try ensureDirectory(logDir)

  var appClean: BuildStepMetrics?
  var appIncr: BuildStepMetrics?
  var appBinary: BinaryMetric?
  var recipeUsed = "default"
  var lastError: Error?
  for recipe in recipes {
    do {
      let derivedData = outputRoot.appendingPathComponent("derived-data/\(label)/\(recipe.name)")
      let schemeToUse = recipe.scheme ?? scheme
      let (clean, incr, binary) = try buildApp(
        repo: repo,
        workspace: workspace,
        scheme: schemeToUse,
        configuration: configuration,
        derivedData: derivedData,
        logDir: logDir,
        runIncremental: runIncrementalFlag,
        extraArgs: recipe.xcodebuild_args,
        recipeName: recipe.name
      )
      appClean = clean
      appIncr = incr
      appBinary = binary
      recipeUsed = recipe.name
      lastError = nil
      break
    } catch {
      lastError = error
    }
  }

  if let lastError {
    throw lastError
  }

  guard let appClean else {
    throw ToolError.commandFailed("App build did not produce metrics.")
  }
  let (cliClean, cliIncr, cliBinaries) = try buildCli(
    repo: repo,
    configuration: configuration,
    logDir: logDir,
    runIncremental: runIncrementalFlag
  )

  let tests: TestMetrics
  if runTestsFlag {
    tests = try runTests(
      repo: repo,
      configuration: configuration,
      logDir: logDir,
      allowFailures: allowTestFailures
    )
  } else {
    let log = logDir.appendingPathComponent("tests.log")
    try writeLog("Tests skipped.\n", to: log)
    tests = TestMetrics(duration_seconds: 0, warnings_count: 0, success: true, log_path: log.path)
  }

  return RevisionMetrics(
    sha: sha,
    app: AppMetrics(
      build_recipe: recipeUsed,
      clean_build: appClean,
      incremental_build: appIncr,
      binary: appBinary
    ),
    cli: CliMetrics(clean_build: cliClean, incremental_build: cliIncr, binaries: cliBinaries),
    tests: tests
  )
}

do {
  let options = try parseArgs()
  let repo = try repoRoot()
  let (swiftVersion, xcodeVersion) = try versionInfo()

  try ensureDirectory(options.outputRoot)
  try ensureDirectory(options.worktreeRoot)

  let basePath = options.worktreeRoot.appendingPathComponent("base")
  let headPath = options.worktreeRoot.appendingPathComponent("head")

  var cleanupPaths: [URL] = []
  if !options.keepWorktrees {
    cleanupPaths = [basePath, headPath]
  }

  defer {
    if options.keepWorktrees == false {
      for path in cleanupPaths {
        _ = try? removeWorktree(repo: repo, path: path)
      }
    }
  }

  try addWorktree(repo: repo, path: basePath, sha: options.baseSha)
  try addWorktree(repo: repo, path: headPath, sha: options.headSha)

  let baseWorkspace = try detectWorkspace(in: basePath, override: options.workspace)
  let headWorkspace = try detectWorkspace(in: headPath, override: options.workspace)
  let baseScheme = resolveScheme(
    defaultScheme: options.scheme,
    schemeIsDefault: options.schemeIsDefault,
    workspace: baseWorkspace
  )
  let headScheme = resolveScheme(
    defaultScheme: options.scheme,
    schemeIsDefault: options.schemeIsDefault,
    workspace: headWorkspace
  )
  let config = try loadConfig(repo: repo, overridePath: options.configPath)
  let baseRecipes = config?.appRecipes(forWorkspace: baseWorkspace) ?? defaultAppRecipes()
  let headRecipes = config?.appRecipes(forWorkspace: headWorkspace) ?? defaultAppRecipes()

  let baseMetrics = try runForRevision(
    label: "base",
    sha: options.baseSha,
    repo: basePath,
    workspace: baseWorkspace,
    scheme: baseScheme,
    recipes: baseRecipes,
    configuration: options.configuration,
    outputRoot: options.outputRoot,
    runTestsFlag: options.runTests,
    allowTestFailures: options.allowTestFailures,
    runIncrementalFlag: options.runIncremental
  )

  let headMetrics = try runForRevision(
    label: "head",
    sha: options.headSha,
    repo: headPath,
    workspace: headWorkspace,
    scheme: headScheme,
    recipes: headRecipes,
    configuration: options.configuration,
    outputRoot: options.outputRoot,
    runTestsFlag: options.runTests,
    allowTestFailures: options.allowTestFailures,
    runIncrementalFlag: options.runIncremental
  )

  let metadata = RunMetadata(
    timestamp_utc: ISO8601DateFormatter().string(from: Date()),
    repo_root: repo.path,
    base_sha: options.baseSha,
    head_sha: options.headSha,
    worktree_root: options.worktreeRoot.path,
    output_root: options.outputRoot.path,
    scheme: options.scheme,
    configuration: options.configuration,
    swift_version: swiftVersion,
    xcode_version: xcodeVersion
  )

  let report = Report(schema_version: 2, run: metadata, base: baseMetrics, head: headMetrics)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let jsonData = try encoder.encode(report)
  let jsonPath = options.outputRoot.appendingPathComponent("report.json")
  try jsonData.write(to: jsonPath)

  let md = markdownReport(base: baseMetrics, head: headMetrics, metadata: metadata)
  let mdPath = options.outputRoot.appendingPathComponent("REPORT.md")
  try md.write(to: mdPath, atomically: true, encoding: .utf8)

  print("Build compare complete.")
  print("Report: \(mdPath.path)")
  print("JSON:   \(jsonPath.path)")
} catch {
  if let toolError = error as? ToolError {
    fputs("Error: \(toolError.description)\n", stderr)
  } else {
    fputs("Error: \(error)\n", stderr)
  }
  exit(1)
}
