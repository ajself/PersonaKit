import BuildCompareCore
import Foundation

extension BuildCompareCLI {
  private struct VersionInfo {
    let swift: String
    let xcode: String
  }

  private struct RunContext {
    let options: Options
    let repo: URL
    let versions: VersionInfo
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
    let base: RevisionMetrics
    let head: RevisionMetrics
  }

  private struct OutputPaths {
    let json: URL
    let markdown: URL
  }

  static func run() throws {
    let context = try makeRunContext()
    try withWorktrees(context: context) { worktrees in
      let workspacePlan = try resolveWorkspaces(context: context, worktrees: worktrees)
      let recipePlan = try resolveRecipes(context: context, workspacePlan: workspacePlan)
      let metrics = try runComparisons(
        context: context,
        worktrees: worktrees,
        workspacePlan: workspacePlan,
        recipePlan: recipePlan
      )
      let metadata = buildMetadata(context: context, worktrees: worktrees)
      let outputPaths = try writeReports(
        metrics: metrics,
        metadata: metadata,
        outputRoot: context.options.outputRoot
      )
      print("Build compare complete.")
      print("Report: \(outputPaths.markdown.path)")
      print("JSON:   \(outputPaths.json.path)")
    }
  }

  private static func makeRunContext() throws -> RunContext {
    let options = try parseArgs()
    let repo = try repoRoot()
    let versions = try versionInfo()
    try ensureDirectory(options.outputRoot)
    try ensureDirectory(options.worktreeRoot)
    return RunContext(
      options: options,
      repo: repo,
      versions: VersionInfo(swift: versions.swift, xcode: versions.xcode)
    )
  }

  private static func withWorktrees(
    context: RunContext,
    body: (WorktreePaths) throws -> Void
  ) throws {
    let worktrees = WorktreePaths(
      base: context.options.worktreeRoot.appendingPathComponent("base"),
      head: context.options.worktreeRoot.appendingPathComponent("head")
    )

    let cleanupPaths = context.options.keepWorktrees ? [] : [worktrees.base, worktrees.head]
    defer {
      if context.options.keepWorktrees == false {
        for path in cleanupPaths {
          _ = try? removeWorktree(repo: context.repo, path: path)
        }
      }
    }

    try addWorktree(repo: context.repo, path: worktrees.base, sha: context.options.baseSha)
    try addWorktree(repo: context.repo, path: worktrees.head, sha: context.options.headSha)
    try body(worktrees)
  }

  private static func resolveWorkspaces(
    context: RunContext,
    worktrees: WorktreePaths
  ) throws -> WorkspacePlan {
    let baseWorkspace = try detectWorkspace(in: worktrees.base, override: context.options.workspace)
    let headWorkspace = try detectWorkspace(in: worktrees.head, override: context.options.workspace)
    let baseScheme = resolveScheme(
      defaultScheme: context.options.scheme,
      schemeIsDefault: context.options.schemeIsDefault,
      workspace: baseWorkspace
    )
    let headScheme = resolveScheme(
      defaultScheme: context.options.scheme,
      schemeIsDefault: context.options.schemeIsDefault,
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
    context: RunContext,
    workspacePlan: WorkspacePlan
  ) throws -> RecipePlan {
    let config = try loadConfig(repo: context.repo, overridePath: context.options.configPath)
    let baseRecipes = config?.appRecipes(forWorkspace: workspacePlan.baseWorkspace)
      ?? defaultAppRecipes()
    let headRecipes = config?.appRecipes(forWorkspace: workspacePlan.headWorkspace)
      ?? defaultAppRecipes()
    return RecipePlan(base: baseRecipes, head: headRecipes)
  }

  private static func runComparisons(
    context: RunContext,
    worktrees: WorktreePaths,
    workspacePlan: WorkspacePlan,
    recipePlan: RecipePlan
  ) throws -> RunMetrics {
    let baseMetrics = try runForRevision(
      RevisionRunRequest(
        label: "base",
        sha: context.options.baseSha,
        repo: worktrees.base,
        workspace: workspacePlan.baseWorkspace,
        scheme: workspacePlan.baseScheme,
        recipes: recipePlan.base,
        configuration: context.options.configuration,
        outputRoot: context.options.outputRoot,
        runTests: context.options.runTests,
        allowTestFailures: context.options.allowTestFailures,
        runIncremental: context.options.runIncremental
      )
    )

    let headMetrics = try runForRevision(
      RevisionRunRequest(
        label: "head",
        sha: context.options.headSha,
        repo: worktrees.head,
        workspace: workspacePlan.headWorkspace,
        scheme: workspacePlan.headScheme,
        recipes: recipePlan.head,
        configuration: context.options.configuration,
        outputRoot: context.options.outputRoot,
        runTests: context.options.runTests,
        allowTestFailures: context.options.allowTestFailures,
        runIncremental: context.options.runIncremental
      )
    )

    return RunMetrics(base: baseMetrics, head: headMetrics)
  }

  private static func buildMetadata(
    context: RunContext,
    worktrees: WorktreePaths
  ) -> RunMetadata {
    RunMetadata(
      timestampUTC: ISO8601DateFormatter().string(from: Date()),
      repoRoot: context.repo.path,
      baseSha: context.options.baseSha,
      headSha: context.options.headSha,
      worktreeRoot: context.options.worktreeRoot.path,
      outputRoot: context.options.outputRoot.path,
      scheme: context.options.scheme,
      configuration: context.options.configuration,
      swiftVersion: context.versions.swift,
      xcodeVersion: context.versions.xcode
    )
  }

  private static func writeReports(
    metrics: RunMetrics,
    metadata: RunMetadata,
    outputRoot: URL
  ) throws -> OutputPaths {
    let report = Report(schemaVersion: 2, run: metadata, base: metrics.base, head: metrics.head)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(report)
    let jsonPath = outputRoot.appendingPathComponent("report.json")
    try jsonData.write(to: jsonPath)

    let markdown = markdownReport(base: metrics.base, head: metrics.head, metadata: metadata)
    let markdownPath = outputRoot.appendingPathComponent("REPORT.md")
    try markdown.write(to: markdownPath, atomically: true, encoding: .utf8)
    return OutputPaths(json: jsonPath, markdown: markdownPath)
  }
}
