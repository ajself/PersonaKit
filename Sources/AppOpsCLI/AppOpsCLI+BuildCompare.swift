import AppOpsCore
import Foundation

extension AppOpsCLI {
  struct BuildCompareInputs {
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

  private struct CommandResult {
    let exitCode: Int32
    let output: String
    let duration: TimeInterval
  }

  private enum BuildCompareError: Error, CustomStringConvertible {
    case usage(String)
    case commandFailed(String)
    case notFound(String)

    var description: String {
      switch self {
      case .usage(let message):
        return message
      case .commandFailed(let message):
        return message
      case .notFound(let message):
        return message
      }
    }
  }

  private struct BuildCompareVersionInfo {
    let swift: String
    let xcode: String
  }

  private struct BuildCompareContext {
    let inputs: BuildCompareInputs
    let repo: URL
    let versions: BuildCompareVersionInfo
  }

  private struct WorktreePaths {
    let base: URL
    let head: URL
  }

  private struct WorkspacePlan {
    let baseWorkspace: String
    let headWorkspace: String
    let baseScheme: String
    let headScheme: String
  }

  private struct RecipePlan {
    let base: [AppBuildRecipe]
    let head: [AppBuildRecipe]
  }

  private struct RunMetrics {
    let base: BuildCompareRevisionMetrics
    let head: BuildCompareRevisionMetrics
  }

  struct BuildAppRequest {
    let repo: URL
    let workspace: String
    let scheme: String
    let configuration: String
    let derivedData: URL
    let logDir: URL
    let runIncremental: Bool
    let extraArgs: [String]
    let recipeName: String
  }

  struct BuildAppResult {
    let clean: BuildStepMetrics
    let incremental: BuildStepMetrics?
    let binary: BinaryMetric?
  }

  struct BuildCliRequest {
    let repo: URL
    let configuration: String
    let logDir: URL
    let runIncremental: Bool
  }

  struct BuildCliResult {
    let clean: BuildStepMetrics
    let incremental: BuildStepMetrics?
    let binaries: [BinaryMetric]
  }

  struct RevisionRunRequest {
    let label: String
    let sha: String
    let repo: URL
    let workspace: String
    let scheme: String
    let recipes: [AppBuildRecipe]
    let configuration: String
    let outputRoot: URL
    let runTests: Bool
    let allowTestFailures: Bool
    let runIncremental: Bool
  }

  private struct AppRecipeBuildOutcome {
    let result: BuildAppResult
    let recipeName: String
  }

  private struct TestRunRequest {
    let repo: URL
    let configuration: String
    let logDir: URL
    let allowFailures: Bool
  }

  static func runBuildCompare(
    inputs: BuildCompareInputs,
    repoRoot: URL,
    environment: AppOpsEnvironment
  ) throws -> BuildCompareReport {
    try ensureDirectory(inputs.outputRoot)
    try ensureDirectory(inputs.worktreeRoot)

    let versions = BuildCompareVersionInfo(
      swift: environment.runCommand(["swift", "--version"]) ?? "unknown",
      xcode: environment.runCommand(["xcodebuild", "-version"]) ?? "unknown"
    )
    let context = BuildCompareContext(inputs: inputs, repo: repoRoot, versions: versions)

    return try withWorktrees(context: context) { worktrees in
      let workspacePlan = try resolveWorkspaces(context: context, worktrees: worktrees)
      let recipePlan = try resolveRecipes(context: context, workspacePlan: workspacePlan)
      let metrics = try runComparisons(
        context: context,
        worktrees: worktrees,
        workspacePlan: workspacePlan,
        recipePlan: recipePlan
      )
      let metadata = buildMetadata(context: context, worktrees: worktrees)
      return BuildCompareReport(
        schemaVersion: 2,
        run: metadata,
        base: metrics.base,
        head: metrics.head
      )
    }
  }

  private static func withWorktrees<T>(
    context: BuildCompareContext,
    body: (WorktreePaths) throws -> T
  ) throws -> T {
    let worktrees = WorktreePaths(
      base: context.inputs.worktreeRoot.appendingPathComponent("base"),
      head: context.inputs.worktreeRoot.appendingPathComponent("head")
    )

    let cleanupPaths = context.inputs.keepWorktrees ? [] : [worktrees.base, worktrees.head]
    defer {
      if context.inputs.keepWorktrees == false {
        for path in cleanupPaths {
          _ = try? removeWorktree(repo: context.repo, path: path)
        }
      }
    }

    try addWorktree(repo: context.repo, path: worktrees.base, sha: context.inputs.baseSha)
    try addWorktree(repo: context.repo, path: worktrees.head, sha: context.inputs.headSha)
    return try body(worktrees)
  }

  private static func resolveWorkspaces(
    context: BuildCompareContext,
    worktrees: WorktreePaths
  ) throws -> WorkspacePlan {
    let baseWorkspace = try detectWorkspace(in: worktrees.base, override: context.inputs.workspace)
    let headWorkspace = try detectWorkspace(in: worktrees.head, override: context.inputs.workspace)
    let baseScheme = resolveScheme(
      defaultScheme: context.inputs.scheme,
      schemeIsDefault: context.inputs.schemeIsDefault,
      workspace: baseWorkspace
    )
    let headScheme = resolveScheme(
      defaultScheme: context.inputs.scheme,
      schemeIsDefault: context.inputs.schemeIsDefault,
      workspace: headWorkspace
    )
    return WorkspacePlan(
      baseWorkspace: baseWorkspace,
      headWorkspace: headWorkspace,
      baseScheme: baseScheme,
      headScheme: headScheme
    )
  }

  private static func resolveRecipes(
    context: BuildCompareContext,
    workspacePlan: WorkspacePlan
  ) throws -> RecipePlan {
    let config = try loadConfig(repo: context.repo, overridePath: context.inputs.configPath)
    let baseRecipes = config?.appRecipes(forWorkspace: workspacePlan.baseWorkspace)
      ?? defaultAppRecipes()
    let headRecipes = config?.appRecipes(forWorkspace: workspacePlan.headWorkspace)
      ?? defaultAppRecipes()
    return RecipePlan(base: baseRecipes, head: headRecipes)
  }

  private static func runComparisons(
    context: BuildCompareContext,
    worktrees: WorktreePaths,
    workspacePlan: WorkspacePlan,
    recipePlan: RecipePlan
  ) throws -> RunMetrics {
    let baseMetrics = try runForRevision(
      RevisionRunRequest(
        label: "base",
        sha: context.inputs.baseSha,
        repo: worktrees.base,
        workspace: workspacePlan.baseWorkspace,
        scheme: workspacePlan.baseScheme,
        recipes: recipePlan.base,
        configuration: context.inputs.configuration,
        outputRoot: context.inputs.outputRoot,
        runTests: context.inputs.runTests,
        allowTestFailures: context.inputs.allowTestFailures,
        runIncremental: context.inputs.runIncremental
      )
    )

    let headMetrics = try runForRevision(
      RevisionRunRequest(
        label: "head",
        sha: context.inputs.headSha,
        repo: worktrees.head,
        workspace: workspacePlan.headWorkspace,
        scheme: workspacePlan.headScheme,
        recipes: recipePlan.head,
        configuration: context.inputs.configuration,
        outputRoot: context.inputs.outputRoot,
        runTests: context.inputs.runTests,
        allowTestFailures: context.inputs.allowTestFailures,
        runIncremental: context.inputs.runIncremental
      )
    )

    return RunMetrics(base: baseMetrics, head: headMetrics)
  }

  private static func buildMetadata(
    context: BuildCompareContext,
    worktrees: WorktreePaths
  ) -> BuildCompareRunMetadata {
    BuildCompareRunMetadata(
      timestampUTC: ISO8601DateFormatter().string(from: Date()),
      repoRoot: context.repo.path,
      baseSha: context.inputs.baseSha,
      headSha: context.inputs.headSha,
      worktreeRoot: context.inputs.worktreeRoot.path,
      outputRoot: context.inputs.outputRoot.path,
      scheme: context.inputs.scheme,
      configuration: context.inputs.configuration,
      swiftVersion: context.versions.swift,
      xcodeVersion: context.versions.xcode
    )
  }

  /// Runs a tool via `/usr/bin/env`, capturing combined output and elapsed time.
  private static func runTool(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> CommandResult {
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
    return CommandResult(
      exitCode: process.terminationStatus,
      output: output,
      duration: end.timeIntervalSince(start)
    )
  }

  /// Calculates the total size of a directory tree in bytes.
  private static func directorySize(at url: URL) -> Int64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
      return 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
        let size = values.fileSize
      else {
        continue
      }
      total += Int64(size)
    }
    return total
  }

  /// Returns the size of a single file in bytes.
  private static func fileSize(at url: URL) -> Int64 {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? NSNumber
    else {
      return 0
    }
    return size.int64Value
  }

  /// Ensures a directory exists, creating intermediate directories as needed.
  private static func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  /// Writes log text to disk using UTF-8 encoding.
  private static func writeLog(_ text: String, to url: URL) throws {
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Adds a git worktree at the requested path for the given revision.
  private static func addWorktree(repo: URL, path: URL, sha: String) throws {
    let result = try runTool("git", ["worktree", "add", path.path, sha], cwd: repo)
    if result.exitCode != 0 {
      throw BuildCompareError.commandFailed("git worktree add failed:\n\(result.output)")
    }
  }

  /// Removes a git worktree at the requested path.
  private static func removeWorktree(repo: URL, path: URL) throws {
    let result = try runTool("git", ["worktree", "remove", path.path], cwd: repo)
    if result.exitCode != 0 {
      throw BuildCompareError.commandFailed("git worktree remove failed:\n\(result.output)")
    }
  }

  /// Detects the workspace name in a repo, honoring an explicit override.
  private static func detectWorkspace(in repo: URL, override: String?) throws -> String {
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

    throw BuildCompareError.notFound("No .xcworkspace found in \(repo.path). Use --build-workspace to override.")
  }

  /// Selects the scheme, switching defaults for PersonaPad workspaces.
  private static func resolveScheme(
    defaultScheme: String,
    schemeIsDefault: Bool,
    workspace: String
  ) -> String {
    guard schemeIsDefault else { return defaultScheme }
    if workspace == "PersonaPad.xcworkspace", defaultScheme == "PersonaKitApp" {
      return "PersonaPadApp"
    }
    return defaultScheme
  }

  /// Provides the fallback app build recipes when no config is supplied.
  private static func defaultAppRecipes() -> [AppBuildRecipe] {
    [
      AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuildArgs: []),
      AppBuildRecipe(
        name: "legacy-driver",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["SWIFT_USE_INTEGRATED_DRIVER=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-explicit-modules-off",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["SWIFT_ENABLE_EXPLICIT_MODULES=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-build-system",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["-UseNewBuildSystem=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-build-system-driver",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["-UseNewBuildSystem=NO", "SWIFT_USE_INTEGRATED_DRIVER=NO"]
      ),
    ]
  }

  /// Loads a build-compare configuration JSON from disk when available.
  private static func loadConfig(repo: URL, overridePath: String?) throws -> BuildCompareConfig? {
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

  /// Builds the app target and collects timing, warnings, and binary size metrics.
  static func buildApp(request: BuildAppRequest) throws -> BuildAppResult {
    let fm = FileManager.default
    if fm.fileExists(atPath: request.derivedData.path) {
      try? fm.removeItem(at: request.derivedData)
    }
    try ensureDirectory(request.logDir)

    let baseArgs = [
      "-workspace", request.workspace,
      "-scheme", request.scheme,
      "-configuration", request.configuration,
      "-derivedDataPath", request.derivedData.path,
      "CODE_SIGNING_ALLOWED=NO",
      "-showBuildTimingSummary",
    ]
    let buildArgs = baseArgs + request.extraArgs + ["build"]

    let cleanLog = request.logDir.appendingPathComponent("app-clean-\(request.recipeName).log")
    let cleanResult = try runTool("xcodebuild", buildArgs, cwd: request.repo)
    try writeLog(cleanResult.output, to: cleanLog)
    if cleanResult.exitCode != 0 {
      throw BuildCompareError.commandFailed(
        "App clean build failed. Log: \(cleanLog.path)\n\(cleanResult.output)"
      )
    }
    let cleanMetrics = buildAppMetrics(
      result: cleanResult,
      logURL: cleanLog,
      outputPath: request.derivedData.path
    )

    var incrementalMetrics: BuildStepMetrics?
    if request.runIncremental {
      let incrLog = request.logDir.appendingPathComponent("app-incremental-\(request.recipeName).log")
      let incrResult = try runTool("xcodebuild", buildArgs, cwd: request.repo)
      try writeLog(incrResult.output, to: incrLog)
      if incrResult.exitCode != 0 {
        throw BuildCompareError.commandFailed(
          "App incremental build failed. Log: \(incrLog.path)\n\(incrResult.output)"
        )
      }
      incrementalMetrics = buildAppMetrics(
        result: incrResult,
        logURL: incrLog,
        outputPath: request.derivedData.path
      )
    }

    let binaryMetric = appBinaryMetric(
      derivedData: request.derivedData,
      configuration: request.configuration,
      scheme: request.scheme
    )
    return BuildAppResult(clean: cleanMetrics, incremental: incrementalMetrics, binary: binaryMetric)
  }

  /// Builds the CLI target and collects timing, warnings, and binary size metrics.
  static func buildCli(request: BuildCliRequest) throws -> BuildCliResult {
    let fm = FileManager.default
    try ensureDirectory(request.logDir)
    let buildDir = request.repo.appendingPathComponent(".build")
    if fm.fileExists(atPath: buildDir.path) {
      _ = try? runTool("swift", ["package", "clean"], cwd: request.repo)
    }

    let cleanLog = request.logDir.appendingPathComponent("cli-clean.log")
    let cleanResult = try runTool(
      "swift",
      ["build", "-c", request.configuration.lowercased()],
      cwd: request.repo
    )
    try writeLog(cleanResult.output, to: cleanLog)
    if cleanResult.exitCode != 0 {
      throw BuildCompareError.commandFailed(
        "CLI clean build failed. Log: \(cleanLog.path)\n\(cleanResult.output)"
      )
    }
    let cleanMetrics = buildStepMetrics(
      result: cleanResult,
      logURL: cleanLog,
      outputPath: buildDir.path,
      timingSummary: nil
    )

    var incrementalMetrics: BuildStepMetrics?
    if request.runIncremental {
      let incrLog = request.logDir.appendingPathComponent("cli-incremental.log")
      let incrResult = try runTool(
        "swift",
        ["build", "-c", request.configuration.lowercased()],
        cwd: request.repo
      )
      try writeLog(incrResult.output, to: incrLog)
      if incrResult.exitCode != 0 {
        throw BuildCompareError.commandFailed(
          "CLI incremental build failed. Log: \(incrLog.path)\n\(incrResult.output)"
        )
      }
      incrementalMetrics = buildStepMetrics(
        result: incrResult,
        logURL: incrLog,
        outputPath: buildDir.path,
        timingSummary: nil
      )
    }

    let binaries = cliBinaries(repo: request.repo)
    return BuildCliResult(clean: cleanMetrics, incremental: incrementalMetrics, binaries: binaries)
  }

  /// Runs `swift test` and returns timing and warning metrics.
  private static func runTests(request: TestRunRequest) throws -> TestMetrics {
    try ensureDirectory(request.logDir)
    let log = request.logDir.appendingPathComponent("tests.log")
    let result = try runTool(
      "swift",
      ["test", "-c", request.configuration.lowercased()],
      cwd: request.repo
    )
    try writeLog(result.output, to: log)
    let warnings = countWarnings(result.output)
    let success = result.exitCode == 0
    if !success, !request.allowFailures {
      throw BuildCompareError.commandFailed("Tests failed. Log: \(log.path)\n\(result.output)")
    }
    return TestMetrics(
      durationSeconds: result.duration,
      warningsCount: warnings,
      success: success,
      logPath: log.path
    )
  }

  /// Executes all build and test steps for a single revision.
  static func runForRevision(_ request: RevisionRunRequest) throws -> BuildCompareRevisionMetrics {
    let logDir = request.outputRoot.appendingPathComponent("logs/\(request.label)")
    try ensureDirectory(logDir)

    let appOutcome = try buildAppForRevision(request: request, logDir: logDir)
    let cliResult = try buildCli(
      request: BuildCliRequest(
        repo: request.repo,
        configuration: request.configuration,
        logDir: logDir,
        runIncremental: request.runIncremental
      )
    )
    let tests = try testsForRevision(request: request, logDir: logDir)

    return BuildCompareRevisionMetrics(
      sha: request.sha,
      app: AppMetrics(
        buildRecipe: appOutcome.recipeName,
        cleanBuild: appOutcome.result.clean,
        incrementalBuild: appOutcome.result.incremental,
        binary: appOutcome.result.binary
      ),
      cli: CliMetrics(
        cleanBuild: cliResult.clean,
        incrementalBuild: cliResult.incremental,
        binaries: cliResult.binaries
      ),
      tests: tests
    )
  }

  private static func buildAppForRevision(
    request: RevisionRunRequest,
    logDir: URL
  ) throws -> AppRecipeBuildOutcome {
    var lastError: Error?
    for recipe in request.recipes {
      do {
        let derivedData = request.outputRoot.appendingPathComponent(
          "derived-data/\(request.label)/\(recipe.name)"
        )
        let schemeToUse = recipe.scheme ?? request.scheme
        let result = try buildApp(
          request: BuildAppRequest(
            repo: request.repo,
            workspace: request.workspace,
            scheme: schemeToUse,
            configuration: request.configuration,
            derivedData: derivedData,
            logDir: logDir,
            runIncremental: request.runIncremental,
            extraArgs: recipe.xcodebuildArgs,
            recipeName: recipe.name
          )
        )
        return AppRecipeBuildOutcome(result: result, recipeName: recipe.name)
      } catch {
        lastError = error
      }
    }

    if let lastError {
      throw lastError
    }
    throw BuildCompareError.commandFailed("App build did not produce metrics.")
  }

  private static func testsForRevision(
    request: RevisionRunRequest,
    logDir: URL
  ) throws -> TestMetrics {
    if request.runTests {
      return try runTests(
        request: TestRunRequest(
          repo: request.repo,
          configuration: request.configuration,
          logDir: logDir,
          allowFailures: request.allowTestFailures
        )
      )
    }
    let log = logDir.appendingPathComponent("tests.log")
    try writeLog("Tests skipped.\n", to: log)
    return TestMetrics(durationSeconds: 0, warningsCount: 0, success: true, logPath: log.path)
  }

  private static func buildAppMetrics(
    result: CommandResult,
    logURL: URL,
    outputPath: String
  ) -> BuildStepMetrics {
    let timing = parseTimingSummary(result.output)
    return buildStepMetrics(
      result: result,
      logURL: logURL,
      outputPath: outputPath,
      timingSummary: timing.isEmpty ? nil : timing
    )
  }

  private static func buildStepMetrics(
    result: CommandResult,
    logURL: URL,
    outputPath: String,
    timingSummary: [TimingEntry]?
  ) -> BuildStepMetrics {
    BuildStepMetrics(
      durationSeconds: result.duration,
      warningsCount: countWarnings(result.output),
      timingSummary: timingSummary,
      logPath: logURL.path,
      outputPath: outputPath
    )
  }

  private static func appBinaryMetric(
    derivedData: URL,
    configuration: String,
    scheme: String
  ) -> BinaryMetric? {
    let fm = FileManager.default
    let products = derivedData.appendingPathComponent("Build/Products/\(configuration)")
    let appURL = products.appendingPathComponent("\(scheme).app")
    let exeURL = products.appendingPathComponent(scheme)
    if fm.fileExists(atPath: appURL.path) {
      return BinaryMetric(path: appURL.path, sizeBytes: directorySize(at: appURL))
    }
    if fm.fileExists(atPath: exeURL.path) {
      return BinaryMetric(path: exeURL.path, sizeBytes: fileSize(at: exeURL))
    }
    return nil
  }

  private static func cliBinaries(repo: URL) -> [BinaryMetric] {
    let fm = FileManager.default
    let releaseDir = repo.appendingPathComponent(".build/release")
    let binariesToCheck = ["personakit", "personakit-validate"]
    var binaries: [BinaryMetric] = []
    for name in binariesToCheck {
      let path = releaseDir.appendingPathComponent(name)
      if fm.fileExists(atPath: path.path) {
        binaries.append(BinaryMetric(path: path.path, sizeBytes: fileSize(at: path)))
      }
    }
    return binaries
  }
}
