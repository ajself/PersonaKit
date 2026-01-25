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
    let buildCompare: BuildCompareInputs?
    let buildCompareSkippedReason: String?
    let timestamp: String
    let userPacksRoot: String?
  }

  private struct ReportMetrics {
    let reloadSnapshot: ReloadSnapshot
    let compose: ComposeMetrics
    let diff: DiffMetrics
    let importMetrics: ImportMetrics
    let exportMetrics: ExportMetrics
    let buildCompare: BuildCompareReport?
    let buildCompareSkippedReason: String?
  }

  /// Runs the CLI with injected dependencies for testability.
  static func run(arguments: [String], environment: AppOpsEnvironment) throws -> AppOpsRunResult {
    let parsed = parseArgs(arguments)
    if parsed.hasFlag("help") {
      printUsage()
      return AppOpsRunResult(outputRoot: URL(fileURLWithPath: "/"), report: emptyReport())
    }

    let fileClient = environment.fileClient
    let inputs = try resolveRunInputs(parsed: parsed, environment: environment)

    let reloadSnapshot = try runReload(
      repoRoot: inputs.repoRoot,
      builtInURLs: inputs.builtInURLs,
      includeUserPacks: inputs.includeUserPacks,
      fileClient: fileClient
    )

    let composeMetrics = measureCompose(resolved: reloadSnapshot.resolved)
    let diffMetrics = try measureDiff(left: inputs.diffLeft, right: inputs.diffRight)
    let importMetrics = try measureImport(
      selection: inputs.importSource,
      destinationRoot: inputs.outputRoot.appendingPathComponent("import", isDirectory: true),
      fileClient: fileClient
    )

    let exportMetrics = try measureExport(
      sets: reloadSnapshot.builtInSets + reloadSnapshot.userSets,
      outputRoot: inputs.outputRoot.appendingPathComponent("export", isDirectory: true),
      fileClient: fileClient
    )

    let buildCompareReport = try inputs.buildCompare.map { buildInputs in
      try runBuildCompare(inputs: buildInputs, repoRoot: inputs.repoRoot, environment: environment)
    }

    let metrics = ReportMetrics(
      reloadSnapshot: reloadSnapshot,
      compose: composeMetrics,
      diff: diffMetrics,
      importMetrics: importMetrics,
      exportMetrics: exportMetrics,
      buildCompare: buildCompareReport,
      buildCompareSkippedReason: inputs.buildCompareSkippedReason
    )
    let report = makeReport(inputs: inputs, metrics: metrics, environment: environment)

    let jsonURL = inputs.outputRoot.appendingPathComponent("report.json")
    let markdownURL = inputs.outputRoot.appendingPathComponent("REPORT.md")
    try writeReport(report, jsonURL: jsonURL, markdownURL: markdownURL, fileClient: fileClient)

    print("Report written to:")
    print("- \(markdownURL.path)")
    print("- \(jsonURL.path)")
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

    let userPacksRoot = includeUserPacks
      ? PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs.path
      : nil
    let timestamp = isoTimestampUTC(environment.now())
    let outputRoot = outDir.appendingPathComponent(
      "appops-\(fileSafeTimestamp(timestamp))",
      isDirectory: true
    )
    try fileClient.createDirectory(outputRoot, true)

    let buildCompare = try resolveBuildCompareInputs(
      parsed: parsed,
      repoRoot: repoRoot,
      outputRoot: outputRoot,
      includeBuildCompare: !parsed.hasFlag("no-build-compare")
    )

    return RunInputs(
      repoRoot: repoRoot,
      outputRoot: outputRoot,
      includeUserPacks: includeUserPacks,
      builtInURLs: builtInURLs,
      importSource: importSource,
      diffLeft: diffLeft,
      diffRight: diffRight,
      buildCompare: buildCompare.inputs,
      buildCompareSkippedReason: buildCompare.skippedReason,
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

  private struct BuildCompareResolution {
    let inputs: BuildCompareInputs?
    let skippedReason: String?
  }

  private static func resolveBuildCompareInputs(
    parsed: ParsedArgs,
    repoRoot: URL,
    outputRoot: URL,
    includeBuildCompare: Bool
  ) throws -> BuildCompareResolution {
    guard includeBuildCompare else {
      return BuildCompareResolution(
        inputs: nil,
        skippedReason: "disabled via --no-build-compare"
      )
    }

    let baseSha = parsed.value(for: "build-base")
    let headSha = parsed.value(for: "build-head")
    if baseSha == nil, headSha == nil {
      return BuildCompareResolution(
        inputs: nil,
        skippedReason: "missing --build-base/--build-head"
      )
    }
    guard let baseSha, let headSha else {
      throw AppOpsError("Build compare requires both --build-base and --build-head.")
    }

    let buildOutputRoot = outputRoot.appendingPathComponent("build-compare", isDirectory: true)
    let worktreeRoot: URL
    if let override = parsed.value(for: "build-worktree-root") {
      worktreeRoot = resolvePath(override, relativeTo: repoRoot)
    } else {
      worktreeRoot = buildOutputRoot.appendingPathComponent("worktrees", isDirectory: true)
    }

    let scheme = parsed.value(for: "build-scheme") ?? "PersonaKitApp"
    let schemeIsDefault = parsed.value(for: "build-scheme") == nil
    let configuration = parsed.value(for: "build-configuration") ?? "Release"
    let workspace = parsed.value(for: "build-workspace")
    let configPath = parsed.value(for: "build-config").map { value in
      resolvePath(value, relativeTo: repoRoot).path
    }

    let inputs = BuildCompareInputs(
      baseSha: baseSha,
      headSha: headSha,
      outputRoot: buildOutputRoot,
      worktreeRoot: worktreeRoot,
      workspace: workspace,
      scheme: scheme,
      schemeIsDefault: schemeIsDefault,
      configuration: configuration,
      configPath: configPath,
      allowTestFailures: parsed.hasFlag("build-allow-test-failures"),
      keepWorktrees: parsed.hasFlag("build-keep-worktrees"),
      runTests: !parsed.hasFlag("build-no-tests"),
      runIncremental: !parsed.hasFlag("build-no-incremental")
    )

    return BuildCompareResolution(inputs: inputs, skippedReason: nil)
  }

  private static func makeReport(
    inputs: RunInputs,
    metrics: ReportMetrics,
    environment: AppOpsEnvironment
  ) -> AppOpsReport {
    AppOpsReport(
      schemaVersion: 2,
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
      buildCompare: metrics.buildCompare,
      buildCompareSkippedReason: metrics.buildCompareSkippedReason
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
        --build-base <sha>      Base git SHA for build-compare (default: skip build compare)
        --build-head <sha>      Head git SHA for build-compare (default: skip build compare)
        --build-workspace <name>    Xcode workspace (default: auto-detect)
        --build-scheme <name>       Xcode scheme (default: PersonaKitApp)
        --build-configuration <name>  Build configuration (default: Release)
        --build-config <path>       JSON config for app build recipes (default: Scripts/build-compare.json if present)
        --build-allow-test-failures Record test failures without aborting the run
        --build-no-tests             Skip swift test during build compare
        --build-no-incremental       Skip incremental builds during build compare
        --build-keep-worktrees       Keep worktrees after build compare
        --build-worktree-root <path> Worktree root override (default: <appops-output>/build-compare/worktrees)
        --no-build-compare       Skip build compare even if SHAs are provided
        --help                  Show this message

      Methodology summary:
        Reload pipeline = built-in load + user-pack load (if enabled) + merge + resolve.
        Compose = render prompt + pretty JSON per persona using sample section values; count UTF-8 bytes.
        Diff = compare left/right packs by persona content hash to count added/removed/modified.
        Import = plan (scan) + copy to temp + move into destination; count files and bytes copied.
        Export = write first available pack set as sorted-key JSON; report bytes written.
        Timing uses a monotonic clock around each step; report formatting is not timed.
        Build compare runs xcodebuild + swift build/test for base/head SHAs in git worktrees.
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
      schemaVersion: 2,
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
      buildCompare: nil,
      buildCompareSkippedReason: nil
    )
  }
}
