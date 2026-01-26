import AppOpsCore
import Foundation
import PersonaKitCore

extension AppOpsCLI {
  private struct ParsedArgs {
    var values: [String: String] = [:]
    var flags: Set<String> = []

    func value(for key: String) -> String? {
      values[key]
    }

    func hasFlag(_ key: String) -> Bool {
      flags.contains(key)
    }
  }

  private struct RunInputs {
    let repoRoot: URL
    let outputRoot: URL
    let includeUserPacks: Bool
    let builtInURLs: [URL]
    let importSource: URL
    let diffLeft: URL
    let diffRight: URL
    let buildRun: BuildRunInputs?
    let buildRunSkippedReason: String?
    let timestamp: String
    let userPacksRoot: String?
  }

  private struct ReportMetrics {
    let reloadSnapshot: ReloadSnapshot
    let compose: ComposeMetrics
    let diff: DiffMetrics
    let importMetrics: ImportMetrics
    let exportMetrics: ExportMetrics
    let buildRun: BuildRunReport?
    let buildRunSkippedReason: String?
  }

  /// Runs the CLI with injected dependencies for testability.
  static func run(arguments: [String], environment: AppOpsEnvironment) throws -> AppOpsRunResult {
    let parsed = parseArgs(arguments)
    if parsed.hasFlag("help") {
      printUsage()
      return AppOpsRunResult(outputRoot: URL(fileURLWithPath: "/"), report: emptyReport())
    }

    let logger = try configureLogger(parsed: parsed, arguments: arguments)

    let fileClient = environment.fileClient
    let inputs = try resolveRunInputs(parsed: parsed, environment: environment)
    logInputs(logger: logger, inputs: inputs)

    let reloadSnapshot = try runReloadStep(
      inputs: inputs,
      fileClient: fileClient,
      logger: logger
    )

    let composeMetrics = runComposeStep(reloadSnapshot: reloadSnapshot, logger: logger)
    let diffMetrics = try runDiffStep(inputs: inputs, logger: logger)
    let importMetrics = try runImportStep(inputs: inputs, fileClient: fileClient, logger: logger)
    let exportMetrics = try runExportStep(
      inputs: inputs,
      reloadSnapshot: reloadSnapshot,
      fileClient: fileClient,
      logger: logger
    )
    let buildRunReport = try runBuildRunStep(
      inputs: inputs,
      environment: environment,
      logger: logger
    )

    let metrics = ReportMetrics(
      reloadSnapshot: reloadSnapshot,
      compose: composeMetrics,
      diff: diffMetrics,
      importMetrics: importMetrics,
      exportMetrics: exportMetrics,
      buildRun: buildRunReport,
      buildRunSkippedReason: inputs.buildRunSkippedReason
    )
    let report = makeReport(inputs: inputs, metrics: metrics, environment: environment)

    try writeReportStep(
      inputs: inputs,
      report: report,
      fileClient: fileClient,
      logger: logger
    )
    logger.info("AppOps finished.")
    return AppOpsRunResult(outputRoot: inputs.outputRoot, report: report)
  }

  private static func resolveRunInputs(
    parsed: ParsedArgs,
    environment: AppOpsEnvironment
  ) throws -> RunInputs {
    let fileClient = environment.fileClient
    let repoRoot = try environment.repoRoot()
    let outDir = resolvePath(parsed.value(for: "out-dir") ?? "Artifacts", relativeTo: repoRoot)
    let includeUserPacks = !parsed.hasFlag("no-user-packs")
    let builtInURLs = environment.builtInPackURLs(repoRoot)
    guard !builtInURLs.isEmpty else {
      throw AppOpsError("Built-in packs not found. Fix: ensure PersonaKitResources are available.")
    }

    let importSource = resolvePath(
      parsed.value(for: "import-source") ?? "Examples/personakit.pack.json",
      relativeTo: repoRoot
    )
    let diffLeft = resolvePath(
      parsed.value(for: "diff-left") ?? builtInURLs[0].path,
      relativeTo: repoRoot
    )
    let diffRight = resolvePath(
      parsed.value(for: "diff-right") ?? "Examples/personakit.pack.json",
      relativeTo: repoRoot
    )

    try ensureFileExists(importSource, label: "Import source", fileClient: fileClient)
    try ensureFileExists(diffLeft, label: "Diff-left pack", fileClient: fileClient)
    try ensureFileExists(diffRight, label: "Diff-right pack", fileClient: fileClient)

    let userPacksRoot =
      includeUserPacks
      ? PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs.path
      : nil
    let timestamp = isoTimestampUTC(environment.now())
    let outputRoot = outDir.appendingPathComponent(
      "appops-\(fileSafeTimestamp(timestamp))",
      isDirectory: true
    )
    try fileClient.createDirectory(outputRoot, true)

    let buildRun = try resolveBuildRunInputs(
      parsed: parsed,
      repoRoot: repoRoot,
      outputRoot: outputRoot,
      includeBuildRun: !parsed.hasFlag("no-build-run")
    )

    return RunInputs(
      repoRoot: repoRoot,
      outputRoot: outputRoot,
      includeUserPacks: includeUserPacks,
      builtInURLs: builtInURLs,
      importSource: importSource,
      diffLeft: diffLeft,
      diffRight: diffRight,
      buildRun: buildRun.inputs,
      buildRunSkippedReason: buildRun.skippedReason,
      timestamp: timestamp,
      userPacksRoot: userPacksRoot
    )
  }

  private static func ensureFileExists(
    _ url: URL,
    label: String,
    fileClient: FileClient
  ) throws {
    guard fileClient.fileExists(url) else {
      throw AppOpsError("\(label) not found: \(url.path)")
    }
  }

  private struct BuildRunResolution {
    let inputs: BuildRunInputs?
    let skippedReason: String?
  }

  private static func resolveBuildRunInputs(
    parsed: ParsedArgs,
    repoRoot: URL,
    outputRoot: URL,
    includeBuildRun: Bool
  ) throws -> BuildRunResolution {
    if parsed.value(for: "build-base") != nil || parsed.value(for: "build-head") != nil {
      throw AppOpsError("Build compare flags were removed. Use --build-sha instead.")
    }
    if parsed.hasFlag("no-build-compare") {
      throw AppOpsError("Use --no-build-run instead of --no-build-compare.")
    }

    guard includeBuildRun else {
      return BuildRunResolution(
        inputs: nil,
        skippedReason: "disabled via --no-build-run"
      )
    }

    let revision = parsed.value(for: "build-sha")

    let buildOutputRoot = outputRoot.appendingPathComponent("build-run", isDirectory: true)
    let worktreePath: URL?
    if let revision {
      if let override = parsed.value(for: "build-worktree-root") {
        worktreePath = resolvePath(override, relativeTo: repoRoot)
      } else {
        worktreePath = buildOutputRoot.appendingPathComponent("worktree", isDirectory: true)
      }
    } else {
      worktreePath = nil
    }

    let scheme = parsed.value(for: "build-scheme") ?? "PersonaKitApp"
    let configuration = parsed.value(for: "build-configuration") ?? "Release"
    let workspace = parsed.value(for: "build-workspace")
    let configPath = parsed.value(for: "build-config").map { value in
      resolvePath(value, relativeTo: repoRoot).path
    }

    let inputs = BuildRunInputs(
      revision: revision,
      outputRoot: buildOutputRoot,
      worktreePath: worktreePath,
      workspace: workspace,
      scheme: scheme,
      configuration: configuration,
      configPath: configPath,
      allowTestFailures: parsed.hasFlag("build-allow-test-failures"),
      keepWorktree: parsed.hasFlag("build-keep-worktrees"),
      runTests: !parsed.hasFlag("build-no-tests"),
      runIncremental: !parsed.hasFlag("build-no-incremental")
    )

    return BuildRunResolution(inputs: inputs, skippedReason: nil)
  }

  private static func makeReport(
    inputs: RunInputs,
    metrics: ReportMetrics,
    environment: AppOpsEnvironment
  ) -> AppOpsReport {
    AppOpsReport(
      schemaVersion: 3,
      run: RunMetadata(
        timestampUTC: inputs.timestamp,
        repoRoot: inputs.repoRoot.path,
        outputRoot: inputs.outputRoot.path,
        gitSha: environment.runCommand(["git", "rev-parse", "HEAD"]) ?? "unknown"
      ),
      environment: EnvironmentInfo(
        macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        swiftVersion: environment.runCommand(["swift", "--version"]) ?? "unknown",
        xcodeVersion: environment.runCommand(["xcodebuild", "-version"]) ?? "unknown"
      ),
      inputs: InputConfig(
        builtInSources: inputs.builtInURLs.map(\.path),
        userPacksRoot: inputs.userPacksRoot,
        includeUserPacks: inputs.includeUserPacks,
        importSource: inputs.importSource.path,
        diffLeft: inputs.diffLeft.path,
        diffRight: inputs.diffRight.path
      ),
      reload: metrics.reloadSnapshot.metrics,
      compose: metrics.compose,
      diff: metrics.diff,
      importMetrics: metrics.importMetrics,
      exportMetrics: metrics.exportMetrics,
      buildRun: metrics.buildRun,
      buildRunSkippedReason: metrics.buildRunSkippedReason
    )
  }

  private static func writeReport(
    _ report: AppOpsReport,
    jsonURL: URL,
    markdownURL: URL,
    fileClient: FileClient
  ) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    try fileClient.writeData(data, jsonURL, .atomic)

    let markdown = AppOpsReportFormatter.markdown(report: report)
    guard let markdownData = markdown.data(using: .utf8) else {
      throw AppOpsError("Failed to encode markdown report.")
    }
    try fileClient.writeData(markdownData, markdownURL, .atomic)
  }

  private static func resolvePath(_ path: String, relativeTo root: URL) -> URL {
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: path, relativeTo: root).standardizedFileURL
  }

  private static func isoTimestampUTC(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func fileSafeTimestamp(_ timestamp: String) -> String {
    timestamp.replacingOccurrences(of: ":", with: "-")
  }

  private static func printUsage() {
    print(
      """
      Usage:
        Scripts/appops [options]

      Options:
        --out-dir <path>        Output directory (default: Artifacts/)
        --import-source <path>  Pack file or folder to import (default: Examples/personakit.pack.json)
        --diff-left <path>      Left pack file for diff (default: built-in pack)
        --diff-right <path>     Right pack file for diff (default: Examples/personakit.pack.json)
        --no-user-packs         Skip loading ~/Library/Application Support/PersonaKit/Packs
        --build-sha <sha>       Git SHA to run build metrics against (default: current working tree)
        --build-workspace <name>    Xcode workspace (default: auto-detect)
        --build-scheme <name>       Xcode scheme (default: PersonaKitApp)
        --build-configuration <name>  Build configuration (default: Release)
        --build-config <path>       JSON config for app build recipes (default: Scripts/build-run.json if present)
        --build-allow-test-failures Record test failures without aborting the run
        --build-no-tests             Skip swift test during build run
        --build-no-incremental       Skip incremental builds during build run
        --build-keep-worktrees       Keep worktree after build run
        --build-worktree-root <path> Worktree path override (default: <appops-output>/build-run/worktree)
        --no-build-run           Skip build run
        --log-level <level>      Log level: trace|debug|info|notice|warning|error|critical (default: info)
        --help                  Show this message

      Methodology summary:
        Reload pipeline = built-in load + user-pack load (if enabled) + merge + resolve.
        Compose = render prompt + pretty JSON per persona using sample section values; count UTF-8 bytes.
        Diff = compare left/right packs by persona content hash to count added/removed/modified.
        Import = plan (scan) + copy to temp + move into destination; count files and bytes copied.
        Export = write first available pack set as sorted-key JSON; report bytes written.
        Timing uses a monotonic clock around each step; report formatting is not timed.
        Build run uses xcodebuild + swift build/test for a single revision or working tree.
      """
    )
  }

  private static func parseArgs(_ args: [String]) -> ParsedArgs {
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
        idx += 1
      }
    }
    return parsed
  }

  private static func emptyReport() -> AppOpsReport {
    AppOpsReport(
      schemaVersion: 3,
      run: RunMetadata(timestampUTC: "", repoRoot: "", outputRoot: "", gitSha: ""),
      environment: EnvironmentInfo(macOSVersion: "", swiftVersion: "", xcodeVersion: ""),
      inputs: InputConfig(
        builtInSources: [],
        userPacksRoot: nil,
        includeUserPacks: false,
        importSource: "",
        diffLeft: "",
        diffRight: ""
      ),
      reload: ReloadMetrics(
        totalDurationSeconds: 0,
        builtIn: LoadMetrics(
          durationSeconds: 0, packCount: 0, personaCount: 0, diagnosticsCount: 0),
        userPacks: nil,
        merge: MergeMetrics(durationSeconds: 0, personaCount: 0, diagnosticsCount: 0),
        resolve: ResolveMetrics(durationSeconds: 0, personaCount: 0, diagnosticsCount: 0),
        totalPacks: 0,
        totalPersonas: 0,
        diagnosticsCount: 0
      ),
      compose: ComposeMetrics(
        durationSeconds: 0, personaCount: 0, promptBytesTotal: 0, jsonBytesTotal: 0),
      diff: DiffMetrics(
        durationSeconds: 0,
        leftPersonaCount: 0,
        rightPersonaCount: 0,
        addedCount: 0,
        removedCount: 0,
        modifiedCount: 0
      ),
      importMetrics: ImportMetrics(
        planDurationSeconds: 0,
        copyDurationSeconds: 0,
        filesCopied: 0,
        bytesCopied: 0,
        destinationRoot: ""
      ),
      exportMetrics: ExportMetrics(durationSeconds: 0, bytesWritten: 0, outputPath: ""),
      buildRun: nil,
      buildRunSkippedReason: nil
    )
  }
}
