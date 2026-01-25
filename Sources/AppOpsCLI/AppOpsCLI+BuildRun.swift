import AppOpsCore
import Foundation

extension AppOpsCLI {
  struct BuildRunInputs {
    let revision: String?
    let outputRoot: URL
    let worktreePath: URL?
    let workspace: String?
    let scheme: String
    let configuration: String
    let configPath: String?
    let allowTestFailures: Bool
    let keepWorktree: Bool
    let runTests: Bool
    let runIncremental: Bool
  }

  private struct CommandResult {
    let exitCode: Int32
    let output: String
    let duration: TimeInterval
  }

  private enum BuildRunError: Error, CustomStringConvertible {
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

  private struct BuildRunVersionInfo {
    let swift: String
    let xcode: String
  }

  private struct BuildRunContext {
    let inputs: BuildRunInputs
    let repo: URL
    let versions: BuildRunVersionInfo
  }

  private struct WorktreeContext {
    let repo: URL
    let worktreePath: URL?
  }

  private struct WorkspacePlan {
    let workspace: String
    let scheme: String
  }

  private struct RecipePlan {
    let recipes: [AppBuildRecipe]
  }

  struct BuildAppRequest {
    let label: String
    let sha: String
    let repo: URL
    let workspace: String
    let scheme: String
    let configuration: String
    let derivedData: URL
    let logDir: URL
    let outputRoot: URL
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
    let label: String
    let sha: String
    let repo: URL
    let configuration: String
    let logDir: URL
    let outputRoot: URL
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
    let label: String
    let sha: String
    let repo: URL
    let configuration: String
    let logDir: URL
    let outputRoot: URL
    let allowFailures: Bool
  }

  static func runBuildRun(
    inputs: BuildRunInputs,
    repoRoot: URL,
    environment: AppOpsEnvironment
  ) throws -> BuildRunReport {
    let logger = AppOpsLog.logger
    logger.info("Build run: preparing output.")
    try ensureDirectory(inputs.outputRoot)
    if let worktreePath = inputs.worktreePath {
      logger.debug("Build run: worktree path \(worktreePath.path)")
      try ensureDirectory(worktreePath.deletingLastPathComponent())
    }

    let versions = BuildRunVersionInfo(
      swift: environment.runCommand(["swift", "--version"]) ?? "unknown",
      xcode: environment.runCommand(["xcodebuild", "-version"]) ?? "unknown"
    )
    let context = BuildRunContext(inputs: inputs, repo: repoRoot, versions: versions)
    if let revision = inputs.revision {
      logger.info("Build run: using revision \(revision).")
    } else {
      logger.info("Build run: using working tree.")
    }

    return try withWorktree(context: context) { worktree in
      let workspacePlan = try resolveWorkspace(context: context, repo: worktree.repo)
      logger.info("Build run: workspace \(workspacePlan.workspace), scheme \(workspacePlan.scheme).")
      let recipePlan = try resolveRecipes(context: context, workspacePlan: workspacePlan)
      logger.info("Build run: resolved \(recipePlan.recipes.count) app recipe(s).")
      logger.debug("Build run: recipes \(recipePlan.recipes.map(\.name).joined(separator: \", \")).")
      let resolvedSha = try resolveRevisionSha(repo: worktree.repo)
      logger.info("Build run: resolved revision SHA \(resolvedSha).")
      let metrics = try runForRevision(
        RevisionRunRequest(
          label: "run",
          sha: resolvedSha,
          repo: worktree.repo,
          workspace: workspacePlan.workspace,
          scheme: workspacePlan.scheme,
          recipes: recipePlan.recipes,
          configuration: context.inputs.configuration,
          outputRoot: context.inputs.outputRoot,
          runTests: context.inputs.runTests,
          allowTestFailures: context.inputs.allowTestFailures,
          runIncremental: context.inputs.runIncremental
        )
      )
      let metadata = buildMetadata(
        context: context,
        worktree: worktree,
        revisionSha: resolvedSha
      )
      logger.info("Build run: metrics collected.")
      return BuildRunReport(
        schemaVersion: 1,
        run: metadata,
        metrics: metrics
      )
    }
  }

  private static func withWorktree<T>(
    context: BuildRunContext,
    body: (WorktreeContext) throws -> T
  ) throws -> T {
    guard let revision = context.inputs.revision else {
      return try body(WorktreeContext(repo: context.repo, worktreePath: nil))
    }
    guard let worktreePath = context.inputs.worktreePath else {
      throw BuildRunError.usage("Missing worktree path for revision \(revision).")
    }

    let cleanupPaths = context.inputs.keepWorktree ? [] : [worktreePath]
    defer {
      if context.inputs.keepWorktree == false {
        for path in cleanupPaths {
          AppOpsLog.logger.info("Build run: removing worktree at \(path.path).")
          _ = try? removeWorktree(repo: context.repo, path: path)
        }
      }
    }

    AppOpsLog.logger.info("Build run: adding worktree for \(revision).")
    try addWorktree(repo: context.repo, path: worktreePath, revision: revision)
    return try body(WorktreeContext(repo: worktreePath, worktreePath: worktreePath))
  }

  private static func resolveWorkspace(
    context: BuildRunContext,
    repo: URL
  ) throws -> WorkspacePlan {
    let workspace = try detectWorkspace(in: repo, override: context.inputs.workspace)
    let scheme = resolveScheme(defaultScheme: context.inputs.scheme)
    return WorkspacePlan(workspace: workspace, scheme: scheme)
  }

  private static func resolveRecipes(
    context: BuildRunContext,
    workspacePlan: WorkspacePlan
  ) throws -> RecipePlan {
    let config = try loadConfig(repo: context.repo, overridePath: context.inputs.configPath)
    let recipes = config?.appRecipes(forWorkspace: workspacePlan.workspace)
      ?? defaultAppRecipes()
    return RecipePlan(recipes: recipes)
  }

  private static func buildMetadata(
    context: BuildRunContext,
    worktree: WorktreeContext,
    revisionSha: String
  ) -> BuildRunMetadata {
    BuildRunMetadata(
      timestampUTC: ISO8601DateFormatter().string(from: Date()),
      repoRoot: context.repo.path,
      revisionSha: revisionSha,
      worktreePath: worktree.worktreePath?.path,
      outputRoot: context.inputs.outputRoot.path,
      scheme: context.inputs.scheme,
      configuration: context.inputs.configuration,
      swiftVersion: context.versions.swift,
      xcodeVersion: context.versions.xcode
    )
  }

  /// Runs a tool via `/usr/bin/env`, capturing combined output and elapsed time.
  private static func runTool(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> CommandResult {
    AppOpsLog.logger.debug("Build run: executing \(tool) \(args.joined(separator: " ")).")
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
    let result = CommandResult(
      exitCode: process.terminationStatus,
      output: output,
      duration: end.timeIntervalSince(start)
    )
    AppOpsLog.logger.debug(
      "Build run: \(tool) exited \(result.exitCode) in \(AppOpsLog.formatSeconds(result.duration))s."
    )
    return result
  }

  private static func resolveRevisionSha(repo: URL) throws -> String {
    let result = try runTool("git", ["rev-parse", "HEAD"], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git rev-parse failed:\n\(result.output)")
    }
    let sha = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    if sha.isEmpty {
      throw BuildRunError.commandFailed("git rev-parse returned an empty SHA.")
    }
    return sha
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

  private static func recordFailure(
    outputRoot: URL,
    label: String,
    sha: String,
    step: String,
    description: String,
    logPath: String,
    output: String
  ) throws -> BuildRunFailure {
    let failuresRoot = outputRoot.appendingPathComponent("failures", isDirectory: true)
    try ensureDirectory(failuresRoot)
    let fileName = "\(label)-\(step).md"
    let detailsURL = failuresRoot.appendingPathComponent(fileName)
    let contents = """
    # Build Run Failure
    Revision: \(sha)
    Step: \(step)
    Description: \(description)
    Log: \(logPath)

    ## Output
    \(output)
    """
    try writeLog(contents, to: detailsURL)
    return BuildRunFailure(
      step: step,
      description: description,
      logPath: logPath,
      detailsPath: detailsURL.path
    )
  }

  /// Adds a git worktree at the requested path for the given revision.
  private static func addWorktree(repo: URL, path: URL, revision: String) throws {
    let result = try runTool("git", ["worktree", "add", path.path, revision], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git worktree add failed:\n\(result.output)")
    }
  }

  /// Removes a git worktree at the requested path.
  private static func removeWorktree(repo: URL, path: URL) throws {
    let result = try runTool("git", ["worktree", "remove", path.path], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git worktree remove failed:\n\(result.output)")
    }
  }

  /// Detects the workspace name in a repo, honoring an explicit override.
  private static func detectWorkspace(in repo: URL, override: String?) throws -> String {
    if let override {
      return override
    }
    let fm = FileManager.default
    let preferred = ["PersonaKit.xcworkspace"]
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

    throw BuildRunError.notFound("No .xcworkspace found in \(repo.path). Use --build-workspace to override.")
  }

  /// Selects the scheme, honoring the caller's default.
  private static func resolveScheme(
    defaultScheme: String
  ) -> String {
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

  /// Loads a build-run configuration JSON from disk when available.
  private static func loadConfig(repo: URL, overridePath: String?) throws -> BuildRunConfig? {
    let fm = FileManager.default
    let configURL: URL?
    if let overridePath {
      configURL = URL(fileURLWithPath: overridePath)
    } else {
      let defaultPath = repo.appendingPathComponent("Scripts/build-run.json")
      configURL = fm.fileExists(atPath: defaultPath.path) ? defaultPath : nil
    }

    guard let url = configURL else { return nil }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(BuildRunConfig.self, from: data)
  }

  /// Builds the app target and collects timing, warnings, and binary size metrics.
  static func buildApp(request: BuildAppRequest) throws -> BuildAppResult {
    let logger = AppOpsLog.logger
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
    logger.info("Build run: app clean build (\(request.recipeName)) started.")
    let cleanResult = try runTool("xcodebuild", buildArgs, cwd: request.repo)
    try writeLog(cleanResult.output, to: cleanLog)
    let cleanFailure: BuildRunFailure? = cleanResult.exitCode == 0
      ? nil
      : try recordFailure(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: "app-clean",
        description: "App clean build failed (recipe: \(request.recipeName)).",
        logPath: cleanLog.path,
        output: cleanResult.output
      )
    let cleanMetrics = buildAppMetrics(
      result: cleanResult,
      logURL: cleanLog,
      outputPath: request.derivedData.path,
      failure: cleanFailure
    )
    if cleanFailure == nil {
      logger.info(
        "Build run: app clean build (\(request.recipeName)) finished in "
          + "\(AppOpsLog.formatSeconds(cleanMetrics.durationSeconds))s "
          + "(warnings: \(cleanMetrics.warningsCount))."
      )
    } else {
      logger.warning(
        "Build run: app clean build (\(request.recipeName)) failed in "
          + "\(AppOpsLog.formatSeconds(cleanMetrics.durationSeconds))s "
          + "(warnings: \(cleanMetrics.warningsCount))."
      )
    }
    if cleanFailure != nil {
      return BuildAppResult(clean: cleanMetrics, incremental: nil, binary: nil)
    }

    var incrementalMetrics: BuildStepMetrics?
    if request.runIncremental {
      let incrLog = request.logDir.appendingPathComponent("app-incremental-\(request.recipeName).log")
      logger.info("Build run: app incremental build (\(request.recipeName)) started.")
      let incrResult = try runTool("xcodebuild", buildArgs, cwd: request.repo)
      try writeLog(incrResult.output, to: incrLog)
      let incrFailure: BuildRunFailure? = incrResult.exitCode == 0
        ? nil
        : try recordFailure(
          outputRoot: request.outputRoot,
          label: request.label,
          sha: request.sha,
          step: "app-incremental",
          description: "App incremental build failed (recipe: \(request.recipeName)).",
          logPath: incrLog.path,
          output: incrResult.output
        )
      incrementalMetrics = buildAppMetrics(
        result: incrResult,
        logURL: incrLog,
        outputPath: request.derivedData.path,
        failure: incrFailure
      )
      if let incrementalMetrics {
        if incrFailure == nil {
          logger.info(
            "Build run: app incremental build (\(request.recipeName)) finished in "
              + "\(AppOpsLog.formatSeconds(incrementalMetrics.durationSeconds))s "
              + "(warnings: \(incrementalMetrics.warningsCount))."
          )
        } else {
          logger.warning(
            "Build run: app incremental build (\(request.recipeName)) failed in "
              + "\(AppOpsLog.formatSeconds(incrementalMetrics.durationSeconds))s "
              + "(warnings: \(incrementalMetrics.warningsCount))."
          )
        }
      }
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
    let logger = AppOpsLog.logger
    let fm = FileManager.default
    try ensureDirectory(request.logDir)
    let buildDir = request.repo.appendingPathComponent(".build")
    if fm.fileExists(atPath: buildDir.path) {
      _ = try? runTool("swift", ["package", "clean"], cwd: request.repo)
    }

    let cleanLog = request.logDir.appendingPathComponent("cli-clean.log")
    logger.info("Build run: CLI clean build started.")
    let cleanResult = try runTool(
      "swift",
      ["build", "-c", request.configuration.lowercased()],
      cwd: request.repo
    )
    try writeLog(cleanResult.output, to: cleanLog)
    let cleanFailure: BuildRunFailure? = cleanResult.exitCode == 0
      ? nil
      : try recordFailure(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: "cli-clean",
        description: "CLI clean build failed.",
        logPath: cleanLog.path,
        output: cleanResult.output
      )
    let cleanMetrics = buildStepMetrics(
      result: cleanResult,
      logURL: cleanLog,
      outputPath: buildDir.path,
      timingSummary: nil,
      failure: cleanFailure
    )
    if cleanFailure == nil {
      logger.info(
        "Build run: CLI clean build finished in \(AppOpsLog.formatSeconds(cleanMetrics.durationSeconds))s "
          + "(warnings: \(cleanMetrics.warningsCount))."
      )
    } else {
      logger.warning(
        "Build run: CLI clean build failed in \(AppOpsLog.formatSeconds(cleanMetrics.durationSeconds))s "
          + "(warnings: \(cleanMetrics.warningsCount))."
      )
    }
    if cleanFailure != nil {
      return BuildCliResult(clean: cleanMetrics, incremental: nil, binaries: [])
    }

    var incrementalMetrics: BuildStepMetrics?
    if request.runIncremental {
      let incrLog = request.logDir.appendingPathComponent("cli-incremental.log")
      logger.info("Build run: CLI incremental build started.")
      let incrResult = try runTool(
        "swift",
        ["build", "-c", request.configuration.lowercased()],
        cwd: request.repo
      )
      try writeLog(incrResult.output, to: incrLog)
      let incrFailure: BuildRunFailure? = incrResult.exitCode == 0
        ? nil
        : try recordFailure(
          outputRoot: request.outputRoot,
          label: request.label,
          sha: request.sha,
          step: "cli-incremental",
          description: "CLI incremental build failed.",
          logPath: incrLog.path,
          output: incrResult.output
        )
      incrementalMetrics = buildStepMetrics(
        result: incrResult,
        logURL: incrLog,
        outputPath: buildDir.path,
        timingSummary: nil,
        failure: incrFailure
      )
      if let incrementalMetrics {
        if incrFailure == nil {
          logger.info(
            "Build run: CLI incremental build finished in "
              + "\(AppOpsLog.formatSeconds(incrementalMetrics.durationSeconds))s "
              + "(warnings: \(incrementalMetrics.warningsCount))."
          )
        } else {
          logger.warning(
            "Build run: CLI incremental build failed in "
              + "\(AppOpsLog.formatSeconds(incrementalMetrics.durationSeconds))s "
              + "(warnings: \(incrementalMetrics.warningsCount))."
          )
        }
      }
    }

    let binaries = cliBinaries(repo: request.repo)
    return BuildCliResult(clean: cleanMetrics, incremental: incrementalMetrics, binaries: binaries)
  }

  /// Runs `swift test` and returns timing and warning metrics.
  private static func runTests(request: TestRunRequest) throws -> TestMetrics {
    let logger = AppOpsLog.logger
    try ensureDirectory(request.logDir)
    let log = request.logDir.appendingPathComponent("tests.log")
    logger.info("Build run: tests started.")
    let result = try runTool(
      "swift",
      ["test", "-c", request.configuration.lowercased()],
      cwd: request.repo
    )
    try writeLog(result.output, to: log)
    let warnings = countWarnings(result.output)
    let success = result.exitCode == 0
    let failure: BuildRunFailure? = success
      ? nil
      : try recordFailure(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: "tests",
        description: "Tests failed.",
        logPath: log.path,
        output: result.output
      )
    return TestMetrics(
      durationSeconds: result.duration,
      warningsCount: warnings,
      success: success,
      logPath: log.path,
      failure: failure
    )
  }

  /// Executes all build and test steps for a single revision.
  static func runForRevision(_ request: RevisionRunRequest) throws -> BuildRunMetrics {
    let logger = AppOpsLog.logger
    logger.info("Build run: starting build/test for \(request.sha).")
    let logDir = request.outputRoot.appendingPathComponent("logs/\(request.label)")
    try ensureDirectory(logDir)

    let appOutcome = try buildAppForRevision(request: request, logDir: logDir)
    let cliResult = try buildCli(
      request: BuildCliRequest(
        label: request.label,
        sha: request.sha,
        repo: request.repo,
        configuration: request.configuration,
        logDir: logDir,
        outputRoot: request.outputRoot,
        runIncremental: request.runIncremental
      )
    )
    let tests = try testsForRevision(request: request, logDir: logDir)
    logger.info("Build run: completed build/test for \(request.sha).")

    return BuildRunMetrics(
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
    let logger = AppOpsLog.logger
    var lastError: Error?
    var lastOutcome: AppRecipeBuildOutcome?
    for recipe in request.recipes {
      do {
        logger.info("Build run: trying app recipe \(recipe.name).")
        let derivedData = request.outputRoot.appendingPathComponent(
          "derived-data/\(request.label)/\(recipe.name)"
        )
        let schemeToUse = recipe.scheme ?? request.scheme
        let result = try buildApp(
          request: BuildAppRequest(
            label: request.label,
            sha: request.sha,
            repo: request.repo,
            workspace: request.workspace,
            scheme: schemeToUse,
            configuration: request.configuration,
            derivedData: derivedData,
            logDir: logDir,
            outputRoot: request.outputRoot,
            runIncremental: request.runIncremental,
            extraArgs: recipe.xcodebuildArgs,
            recipeName: recipe.name
          )
        )
        let outcome = AppRecipeBuildOutcome(result: result, recipeName: recipe.name)
        if outcome.result.clean.failure == nil {
          return outcome
        }
        logger.warning("Build run: app recipe \(recipe.name) failed clean build; trying next.")
        lastOutcome = outcome
      } catch {
        lastError = error
        logger.warning("Build run: app recipe \(recipe.name) threw error: \(error).")
      }
    }

    if let lastOutcome {
      return lastOutcome
    }
    if let lastError {
      throw lastError
    }
    throw BuildRunError.commandFailed("App build did not produce metrics.")
  }

  private static func testsForRevision(
    request: RevisionRunRequest,
    logDir: URL
  ) throws -> TestMetrics {
    if request.runTests {
      let metrics = try runTests(
        request: TestRunRequest(
          label: request.label,
          sha: request.sha,
          repo: request.repo,
          configuration: request.configuration,
          logDir: logDir,
          outputRoot: request.outputRoot,
          allowFailures: request.allowTestFailures
        )
      )
      if metrics.success {
        AppOpsLog.logger.info(
          "Build run: tests finished in \(AppOpsLog.formatSeconds(metrics.durationSeconds))s "
            + "(warnings: \(metrics.warningsCount))."
        )
      } else {
        AppOpsLog.logger.warning(
          "Build run: tests failed in \(AppOpsLog.formatSeconds(metrics.durationSeconds))s "
            + "(warnings: \(metrics.warningsCount))."
        )
      }
      return metrics
    }
    let log = logDir.appendingPathComponent("tests.log")
    try writeLog("Tests skipped.\n", to: log)
    AppOpsLog.logger.info("Build run: tests skipped.")
    return TestMetrics(durationSeconds: 0, warningsCount: 0, success: true, logPath: log.path)
  }

  private static func buildAppMetrics(
    result: CommandResult,
    logURL: URL,
    outputPath: String,
    failure: BuildRunFailure?
  ) -> BuildStepMetrics {
    let timing = parseTimingSummary(result.output)
    return buildStepMetrics(
      result: result,
      logURL: logURL,
      outputPath: outputPath,
      timingSummary: timing.isEmpty ? nil : timing,
      failure: failure
    )
  }

  private static func buildStepMetrics(
    result: CommandResult,
    logURL: URL,
    outputPath: String,
    timingSummary: [TimingEntry]?,
    failure: BuildRunFailure?
  ) -> BuildStepMetrics {
    BuildStepMetrics(
      durationSeconds: result.duration,
      warningsCount: countWarnings(result.output),
      timingSummary: timingSummary,
      logPath: logURL.path,
      outputPath: outputPath,
      failure: failure
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
