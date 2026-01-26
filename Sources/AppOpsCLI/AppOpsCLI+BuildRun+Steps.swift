import AppOpsCore
import Foundation

extension AppOpsCLI {
  private struct FailureRecordInput {
    let outputRoot: URL
    let label: String
    let sha: String
    let step: String
    let description: String
    let logPath: String
    let output: String
  }

  private enum AppBuildStepKind {
    case clean
    case incremental

    var step: String {
      switch self {
      case .clean: return "app-clean"
      case .incremental: return "app-incremental"
      }
    }

    var label: String {
      switch self {
      case .clean: return "clean"
      case .incremental: return "incremental"
      }
    }

    func logFileName(recipeName: String) -> String {
      "\(step)-\(recipeName).log"
    }

    func description(recipeName: String) -> String {
      switch self {
      case .clean:
        return "App clean build failed (recipe: \(recipeName))."
      case .incremental:
        return "App incremental build failed (recipe: \(recipeName))."
      }
    }
  }

  private enum CliBuildStepKind {
    case clean
    case incremental

    var step: String {
      switch self {
      case .clean: return "cli-clean"
      case .incremental: return "cli-incremental"
      }
    }

    var label: String {
      switch self {
      case .clean: return "clean"
      case .incremental: return "incremental"
      }
    }

    var logFileName: String {
      "\(step).log"
    }

    var description: String {
      switch self {
      case .clean:
        return "CLI clean build failed."
      case .incremental:
        return "CLI incremental build failed."
      }
    }
  }

  /// Builds the app target and collects timing, warnings, and binary size metrics.
  static func buildApp(request: BuildAppRequest) throws -> BuildAppResult {
    let fm = FileManager.default
    if fm.fileExists(atPath: request.derivedData.path) {
      try? fm.removeItem(at: request.derivedData)
    }
    try ensureDirectory(request.logDir)

    let buildArgs = appBuildArgs(for: request)
    let cleanMetrics = try runAppBuildStep(request: request, buildArgs: buildArgs, kind: .clean)
    if cleanMetrics.failure != nil {
      return BuildAppResult(clean: cleanMetrics, incremental: nil, binary: nil)
    }

    let incrementalMetrics: BuildStepMetrics? = request.runIncremental
      ? try runAppBuildStep(request: request, buildArgs: buildArgs, kind: .incremental)
      : nil

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

    let cleanMetrics = try runCliBuildStep(
      request: request,
      buildDir: buildDir,
      kind: .clean
    )
    if cleanMetrics.failure != nil {
      return BuildCliResult(clean: cleanMetrics, incremental: nil, binaries: [])
    }

    let incrementalMetrics: BuildStepMetrics? = request.runIncremental
      ? try runCliBuildStep(request: request, buildDir: buildDir, kind: .incremental)
      : nil

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
    let failure = try recordFailureIfNeeded(
      exitCode: result.exitCode,
      input: FailureRecordInput(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: "tests",
        description: "Tests failed.",
        logPath: log.path,
        output: result.output
      )
    )
    return TestMetrics(
      durationSeconds: result.duration,
      warningsCount: warnings,
      success: failure == nil,
      logPath: log.path,
      failure: failure
    )
  }

  private static func appBuildArgs(for request: BuildAppRequest) -> [String] {
    let baseArgs = [
      "-workspace", request.workspace,
      "-scheme", request.scheme,
      "-configuration", request.configuration,
      "-derivedDataPath", request.derivedData.path,
      "CODE_SIGNING_ALLOWED=NO",
      "-showBuildTimingSummary",
    ]
    return baseArgs + request.extraArgs + ["build"]
  }

  private static func runAppBuildStep(
    request: BuildAppRequest,
    buildArgs: [String],
    kind: AppBuildStepKind
  ) throws -> BuildStepMetrics {
    let logger = AppOpsLog.logger
    let logURL = request.logDir.appendingPathComponent(kind.logFileName(recipeName: request.recipeName))
    logger.info("Build run: app \(kind.label) build (\(request.recipeName)) started.")
    let result = try runTool("xcodebuild", buildArgs, cwd: request.repo)
    try writeLog(result.output, to: logURL)
    let failure = try recordFailureIfNeeded(
      exitCode: result.exitCode,
      input: FailureRecordInput(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: kind.step,
        description: kind.description(recipeName: request.recipeName),
        logPath: logURL.path,
        output: result.output
      )
    )
    let metrics = buildAppMetrics(
      result: result,
      logURL: logURL,
      outputPath: request.derivedData.path,
      failure: failure
    )
    logBuildStepResult(
      label: "app \(kind.label) build (\(request.recipeName))",
      metrics: metrics
    )
    return metrics
  }

  private static func runCliBuildStep(
    request: BuildCliRequest,
    buildDir: URL,
    kind: CliBuildStepKind
  ) throws -> BuildStepMetrics {
    let logger = AppOpsLog.logger
    let logURL = request.logDir.appendingPathComponent(kind.logFileName)
    logger.info("Build run: CLI \(kind.label) build started.")
    let result = try runTool(
      "swift",
      ["build", "-c", request.configuration.lowercased()],
      cwd: request.repo
    )
    try writeLog(result.output, to: logURL)
    let failure = try recordFailureIfNeeded(
      exitCode: result.exitCode,
      input: FailureRecordInput(
        outputRoot: request.outputRoot,
        label: request.label,
        sha: request.sha,
        step: kind.step,
        description: kind.description,
        logPath: logURL.path,
        output: result.output
      )
    )
    let metrics = buildStepMetrics(
      result: result,
      logURL: logURL,
      outputPath: buildDir.path,
      timingSummary: nil,
      failure: failure
    )
    logBuildStepResult(label: "CLI \(kind.label) build", metrics: metrics)
    return metrics
  }

  private static func recordFailureIfNeeded(
    exitCode: Int32,
    input: FailureRecordInput
  ) throws -> BuildRunFailure? {
    guard exitCode != 0 else { return nil }
    return try recordFailure(input)
  }

  private static func recordFailure(_ input: FailureRecordInput) throws -> BuildRunFailure {
    let failuresRoot = input.outputRoot.appendingPathComponent("failures", isDirectory: true)
    try ensureDirectory(failuresRoot)
    let fileName = "\(input.label)-\(input.step).md"
    let detailsURL = failuresRoot.appendingPathComponent(fileName)
    let contents = """
      # Build Run Failure
      Revision: \(input.sha)
      Step: \(input.step)
      Description: \(input.description)
      Log: \(input.logPath)

      ## Output
      \(input.output)
      """
    try writeLog(contents, to: detailsURL)
    return BuildRunFailure(
      step: input.step,
      description: input.description,
      logPath: input.logPath,
      detailsPath: detailsURL.path
    )
  }

  private static func logBuildStepResult(
    label: String,
    metrics: BuildStepMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
    let warnings = metrics.warningsCount
    if metrics.failure == nil {
      AppOpsLog.logger.info(
        "Build run: \(label) finished in \(duration)s (warnings: \(warnings))."
      )
    } else {
      AppOpsLog.logger.warning(
        "Build run: \(label) failed in \(duration)s (warnings: \(warnings))."
      )
    }
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
