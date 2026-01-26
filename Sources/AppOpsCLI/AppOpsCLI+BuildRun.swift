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

  struct CommandResult {
    let exitCode: Int32
    let output: String
    let duration: TimeInterval
  }

  enum BuildRunError: Error, CustomStringConvertible {
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

  struct TestRunRequest {
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
      let recipeNames = recipePlan.recipes.map(\.name).joined(separator: ", ")
      logger.debug("Build run: recipes \(recipeNames).")
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
    let recipes =
      config?.appRecipes(forWorkspace: workspacePlan.workspace)
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
        let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
        let warnings = metrics.warningsCount
        AppOpsLog.logger.info(
          "Build run: tests finished in \(duration)s (warnings: \(warnings))."
        )
      } else {
        let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
        let warnings = metrics.warningsCount
        AppOpsLog.logger.warning(
          "Build run: tests failed in \(duration)s (warnings: \(warnings))."
        )
      }
      return metrics
    }
    let log = logDir.appendingPathComponent("tests.log")
    try writeLog("Tests skipped.\n", to: log)
    AppOpsLog.logger.info("Build run: tests skipped.")
    return TestMetrics(durationSeconds: 0, warningsCount: 0, success: true, logPath: log.path)
  }
}
