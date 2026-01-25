import BuildCompareCore
import Foundation

extension BuildCompareCLI {
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
      throw ToolError.commandFailed(
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
        throw ToolError.commandFailed(
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
      throw ToolError.commandFailed(
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
        throw ToolError.commandFailed(
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
  static func runTests(request: TestRunRequest) throws -> TestMetrics {
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
      throw ToolError.commandFailed("Tests failed. Log: \(log.path)\n\(result.output)")
    }
    return TestMetrics(
      durationSeconds: result.duration,
      warningsCount: warnings,
      success: success,
      logPath: log.path
    )
  }

  /// Executes all build and test steps for a single revision.
  static func runForRevision(_ request: RevisionRunRequest) throws -> RevisionMetrics {
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

    return RevisionMetrics(
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
    throw ToolError.commandFailed("App build did not produce metrics.")
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
