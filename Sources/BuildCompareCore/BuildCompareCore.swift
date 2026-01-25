import Foundation

/// One entry in an xcodebuild timing summary.
package struct TimingEntry: Codable, Equatable {
  package let name: String
  package let seconds: Double

  package init(name: String, seconds: Double) {
    self.name = name
    self.seconds = seconds
  }
}

/// Metrics captured for a single build or test step.
package struct BuildStepMetrics: Codable, Equatable {
  package let durationSeconds: Double
  package let warningsCount: Int
  package let timingSummary: [TimingEntry]?
  package let logPath: String
  package let outputPath: String?

  package init(
    durationSeconds: Double,
    warningsCount: Int,
    timingSummary: [TimingEntry]?,
    logPath: String,
    outputPath: String?
  ) {
    self.durationSeconds = durationSeconds
    self.warningsCount = warningsCount
    self.timingSummary = timingSummary
    self.logPath = logPath
    self.outputPath = outputPath
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case warningsCount = "warnings_count"
    case timingSummary = "timing_summary"
    case logPath = "log_path"
    case outputPath = "output_path"
  }
}

/// Size information for a built binary on disk.
package struct BinaryMetric: Codable, Equatable {
  package let path: String
  package let sizeBytes: Int64

  package init(path: String, sizeBytes: Int64) {
    self.path = path
    self.sizeBytes = sizeBytes
  }

  package enum CodingKeys: String, CodingKey {
    case path
    case sizeBytes = "size_bytes"
  }
}

/// Aggregated metrics for building the macOS app.
package struct AppMetrics: Codable, Equatable {
  package let buildRecipe: String
  package let cleanBuild: BuildStepMetrics
  package let incrementalBuild: BuildStepMetrics?
  package let binary: BinaryMetric?

  package init(
    buildRecipe: String,
    cleanBuild: BuildStepMetrics,
    incrementalBuild: BuildStepMetrics?,
    binary: BinaryMetric?
  ) {
    self.buildRecipe = buildRecipe
    self.cleanBuild = cleanBuild
    self.incrementalBuild = incrementalBuild
    self.binary = binary
  }

  package enum CodingKeys: String, CodingKey {
    case buildRecipe = "build_recipe"
    case cleanBuild = "clean_build"
    case incrementalBuild = "incremental_build"
    case binary
  }
}

/// Aggregated metrics for building command-line tools.
package struct CliMetrics: Codable, Equatable {
  package let cleanBuild: BuildStepMetrics
  package let incrementalBuild: BuildStepMetrics?
  package let binaries: [BinaryMetric]

  package init(
    cleanBuild: BuildStepMetrics,
    incrementalBuild: BuildStepMetrics?,
    binaries: [BinaryMetric]
  ) {
    self.cleanBuild = cleanBuild
    self.incrementalBuild = incrementalBuild
    self.binaries = binaries
  }

  package enum CodingKeys: String, CodingKey {
    case cleanBuild = "clean_build"
    case incrementalBuild = "incremental_build"
    case binaries
  }
}

/// Metrics captured from running the test suite.
package struct TestMetrics: Codable, Equatable {
  package let durationSeconds: Double
  package let warningsCount: Int
  package let success: Bool
  package let logPath: String

  package init(
    durationSeconds: Double,
    warningsCount: Int,
    success: Bool,
    logPath: String
  ) {
    self.durationSeconds = durationSeconds
    self.warningsCount = warningsCount
    self.success = success
    self.logPath = logPath
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case warningsCount = "warnings_count"
    case success
    case logPath = "log_path"
  }
}

/// Metrics captured for a single git revision.
package struct RevisionMetrics: Codable, Equatable {
  package let sha: String
  package let app: AppMetrics
  package let cli: CliMetrics
  package let tests: TestMetrics

  package init(
    sha: String,
    app: AppMetrics,
    cli: CliMetrics,
    tests: TestMetrics
  ) {
    self.sha = sha
    self.app = app
    self.cli = cli
    self.tests = tests
  }
}

/// Metadata that describes the environment and inputs for a run.
package struct RunMetadata: Codable, Equatable {
  package let timestampUTC: String
  package let repoRoot: String
  package let baseSha: String
  package let headSha: String
  package let worktreeRoot: String
  package let outputRoot: String
  package let scheme: String
  package let configuration: String
  package let swiftVersion: String
  package let xcodeVersion: String

  package init(
    timestampUTC: String,
    repoRoot: String,
    baseSha: String,
    headSha: String,
    worktreeRoot: String,
    outputRoot: String,
    scheme: String,
    configuration: String,
    swiftVersion: String,
    xcodeVersion: String
  ) {
    self.timestampUTC = timestampUTC
    self.repoRoot = repoRoot
    self.baseSha = baseSha
    self.headSha = headSha
    self.worktreeRoot = worktreeRoot
    self.outputRoot = outputRoot
    self.scheme = scheme
    self.configuration = configuration
    self.swiftVersion = swiftVersion
    self.xcodeVersion = xcodeVersion
  }

  package enum CodingKeys: String, CodingKey {
    case timestampUTC = "timestamp_utc"
    case repoRoot = "repo_root"
    case baseSha = "base_sha"
    case headSha = "head_sha"
    case worktreeRoot = "worktree_root"
    case outputRoot = "output_root"
    case scheme
    case configuration
    case swiftVersion = "swift_version"
    case xcodeVersion = "xcode_version"
  }
}

/// The full report schema emitted by build-compare.
package struct Report: Codable, Equatable {
  package let schemaVersion: Int
  package let run: RunMetadata
  package let base: RevisionMetrics
  package let head: RevisionMetrics

  package init(
    schemaVersion: Int,
    run: RunMetadata,
    base: RevisionMetrics,
    head: RevisionMetrics
  ) {
    self.schemaVersion = schemaVersion
    self.run = run
    self.base = base
    self.head = head
  }

  package enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case run
    case base
    case head
  }
}

/// Describes an app build recipe and its xcodebuild overrides.
package struct AppBuildRecipe: Codable, Equatable {
  package let name: String
  package let workspace: String?
  package let scheme: String?
  package let xcodebuildArgs: [String]

  package init(
    name: String,
    workspace: String?,
    scheme: String?,
    xcodebuildArgs: [String]
  ) {
    self.name = name
    self.workspace = workspace
    self.scheme = scheme
    self.xcodebuildArgs = xcodebuildArgs
  }

  package enum CodingKeys: String, CodingKey {
    case name
    case workspace
    case scheme
    case xcodebuildArgs = "xcodebuild_args"
  }
}

/// Configuration file schema for build-compare app recipes.
package struct BuildCompareConfig: Codable, Equatable {
  package let schemaVersion: Int
  package let appRecipes: [AppBuildRecipe]

  package init(schemaVersion: Int, appRecipes: [AppBuildRecipe]) {
    self.schemaVersion = schemaVersion
    self.appRecipes = appRecipes
  }

  package enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case appRecipes = "app_recipes"
  }

  /// Filters app recipes, preferring workspace-specific entries.
  package func appRecipes(forWorkspace workspace: String) -> [AppBuildRecipe] {
    let matches = appRecipes.filter { recipe in
      guard let target = recipe.workspace else { return true }
      return target == workspace
    }
    return matches.isEmpty ? appRecipes : matches
  }
}

/// Best-effort warning count from build/test output.
package func countWarnings(_ output: String) -> Int {
  output.split(separator: "\n").filter { $0.contains("warning:") }.count
}

/// Parse xcodebuild timing summary lines into name + seconds entries.
package func parseTimingSummary(_ output: String) -> [TimingEntry] {
  var entries: [TimingEntry] = []
  let pattern = #"^\s*(.+?)\s+([0-9]+(?:\.[0-9]+)?)s$"#
  let regex = try? NSRegularExpression(pattern: pattern, options: [])
  for line in output.split(separator: "\n") {
    let text = String(line)
    guard let regex else { continue }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    if let match = regex.firstMatch(in: text, options: [], range: range),
      match.numberOfRanges == 3,
      let nameRange = Range(match.range(at: 1), in: text),
      let secondsRange = Range(match.range(at: 2), in: text)
    {
      let name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
      let seconds = Double(text[secondsRange]) ?? 0
      if !name.isEmpty {
        entries.append(TimingEntry(name: name, seconds: seconds))
      }
    }
  }
  return entries
}

/// Formats a signed delta for seconds with two decimal places.
package func formatDelta(_ value: Double) -> String {
  let sign = value >= 0 ? "+" : ""
  return String(format: "%@%.2fs", sign, value)
}

/// Formats a signed delta for bytes with no unit conversion.
package func formatBytesDelta(_ value: Int64) -> String {
  let sign = value >= 0 ? "+" : ""
  return "\(sign)\(value)"
}

/// Generates a markdown report comparing two revisions.
package func markdownReport(
  base: RevisionMetrics, head: RevisionMetrics, metadata: RunMetadata
) -> String {
  func delta(_ head: Double, _ base: Double) -> String {
    formatDelta(head - base)
  }

  let appCleanDelta = delta(
    head.app.cleanBuild.durationSeconds, base.app.cleanBuild.durationSeconds)
  let cliCleanDelta = delta(
    head.cli.cleanBuild.durationSeconds, base.cli.cleanBuild.durationSeconds)
  let testDelta = delta(head.tests.durationSeconds, base.tests.durationSeconds)

  var appBinaryDelta = "n/a"
  if let baseApp = base.app.binary, let headApp = head.app.binary {
    appBinaryDelta = formatBytesDelta(headApp.sizeBytes - baseApp.sizeBytes)
  }

  var lines: [String] = []
  lines.append("# Build Compare Report")
  lines.append("")
  lines.append("Base: \(metadata.baseSha)")
  lines.append("Head: \(metadata.headSha)")
  lines.append("Configuration: \(metadata.configuration)")
  lines.append("App build recipes: base=\(base.app.buildRecipe), head=\(head.app.buildRecipe)")
  lines.append("")
  lines.append("## Build Times")
  lines.append("| Metric | Base (s) | Head (s) | Delta |")
  lines.append("| --- | ---: | ---: | ---: |")
  lines.append(
    "| App clean build | \(String(format: "%.2f", base.app.cleanBuild.durationSeconds)) | \(String(format: "%.2f", head.app.cleanBuild.durationSeconds)) | \(appCleanDelta) |"
  )
  if let baseIncr = base.app.incrementalBuild?.durationSeconds,
    let headIncr = head.app.incrementalBuild?.durationSeconds
  {
    lines.append(
      "| App incremental build | \(String(format: "%.2f", baseIncr)) | \(String(format: "%.2f", headIncr)) | \(formatDelta(headIncr - baseIncr)) |"
    )
  }
  lines.append(
    "| CLI clean build | \(String(format: "%.2f", base.cli.cleanBuild.durationSeconds)) | \(String(format: "%.2f", head.cli.cleanBuild.durationSeconds)) | \(cliCleanDelta) |"
  )
  if let baseIncr = base.cli.incrementalBuild?.durationSeconds,
    let headIncr = head.cli.incrementalBuild?.durationSeconds
  {
    lines.append(
      "| CLI incremental build | \(String(format: "%.2f", baseIncr)) | \(String(format: "%.2f", headIncr)) | \(formatDelta(headIncr - baseIncr)) |"
    )
  }
  lines.append(
    "| Tests | \(String(format: "%.2f", base.tests.durationSeconds)) | \(String(format: "%.2f", head.tests.durationSeconds)) | \(testDelta) |"
  )
  lines.append("")
  lines.append("## Test Status")
  lines.append("| Metric | Base | Head |")
  lines.append("| --- | --- | --- |")
  lines.append("| Success | \(base.tests.success) | \(head.tests.success) |")
  lines.append("")
  lines.append("## Binary Sizes (bytes)")
  lines.append("| Binary | Base | Head | Delta |")
  lines.append("| --- | ---: | ---: | ---: |")
  if let baseApp = base.app.binary, let headApp = head.app.binary {
    lines.append(
      "| App | \(baseApp.sizeBytes) | \(headApp.sizeBytes) | \(appBinaryDelta) |"
    )
  } else {
    lines.append("| App | n/a | n/a | n/a |")
  }
  for binary in head.cli.binaries {
    let baseBinary = base.cli.binaries.first {
      $0.path.hasSuffix("/" + URL(fileURLWithPath: binary.path).lastPathComponent)
    }
    if let baseBinary {
      let deltaBytes = binary.sizeBytes - baseBinary.sizeBytes
      lines.append(
        "| \(URL(fileURLWithPath: binary.path).lastPathComponent) | \(baseBinary.sizeBytes) | \(binary.sizeBytes) | \(formatBytesDelta(deltaBytes)) |"
      )
    } else {
      lines.append(
        "| \(URL(fileURLWithPath: binary.path).lastPathComponent) | n/a | \(binary.sizeBytes) | n/a |"
      )
    }
  }
  lines.append("")
  lines.append("## Warnings")
  lines.append("| Metric | Base | Head | Delta |")
  lines.append("| --- | ---: | ---: | ---: |")
  lines.append(
    "| App clean build | \(base.app.cleanBuild.warningsCount) | \(head.app.cleanBuild.warningsCount) | \(head.app.cleanBuild.warningsCount - base.app.cleanBuild.warningsCount) |"
  )
  if let baseIncr = base.app.incrementalBuild?.warningsCount,
    let headIncr = head.app.incrementalBuild?.warningsCount
  {
    lines.append(
      "| App incremental build | \(baseIncr) | \(headIncr) | \(headIncr - baseIncr) |"
    )
  }
  lines.append(
    "| CLI clean build | \(base.cli.cleanBuild.warningsCount) | \(head.cli.cleanBuild.warningsCount) | \(head.cli.cleanBuild.warningsCount - base.cli.cleanBuild.warningsCount) |"
  )
  if let baseIncr = base.cli.incrementalBuild?.warningsCount,
    let headIncr = head.cli.incrementalBuild?.warningsCount
  {
    lines.append(
      "| CLI incremental build | \(baseIncr) | \(headIncr) | \(headIncr - baseIncr) |"
    )
  }
  lines.append(
    "| Tests | \(base.tests.warningsCount) | \(head.tests.warningsCount) | \(head.tests.warningsCount - base.tests.warningsCount) |"
  )
  lines.append("")
  lines.append("## Logs")
  lines.append("- Base logs: \(metadata.outputRoot)/logs/base")
  lines.append("- Head logs: \(metadata.outputRoot)/logs/head")
  lines.append("")
  lines.append("## Notes")
  lines.append("- Builds are sensitive to local environment and cache state.")
  lines.append("- Timing summaries are captured in JSON for detailed inspection.")
  return lines.joined(separator: "\n")
}
