import Foundation

/// One entry in an xcodebuild timing summary.
package struct TimingEntry: Codable, Equatable, Sendable {
  package let name: String
  package let seconds: Double

  package init(name: String, seconds: Double) {
    self.name = name
    self.seconds = seconds
  }
}

/// Metrics captured for a single build or test step.
package struct BuildStepMetrics: Codable, Equatable, Sendable {
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
package struct BinaryMetric: Codable, Equatable, Sendable {
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
package struct AppMetrics: Codable, Equatable, Sendable {
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
package struct CliMetrics: Codable, Equatable, Sendable {
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
package struct TestMetrics: Codable, Equatable, Sendable {
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
package struct BuildCompareRevisionMetrics: Codable, Equatable, Sendable {
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

/// Metadata that describes the environment and inputs for a build-compare run.
package struct BuildCompareRunMetadata: Codable, Equatable, Sendable {
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

/// The build-compare report schema embedded in AppOps output.
package struct BuildCompareReport: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let run: BuildCompareRunMetadata
  package let base: BuildCompareRevisionMetrics
  package let head: BuildCompareRevisionMetrics

  package init(
    schemaVersion: Int,
    run: BuildCompareRunMetadata,
    base: BuildCompareRevisionMetrics,
    head: BuildCompareRevisionMetrics
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
package struct AppBuildRecipe: Codable, Equatable, Sendable {
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
package struct BuildCompareConfig: Codable, Equatable, Sendable {
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
    guard let match = regex.firstMatch(in: text, options: [], range: range),
      match.numberOfRanges == 3,
      let nameRange = Range(match.range(at: 1), in: text),
      let secondsRange = Range(match.range(at: 2), in: text)
    else {
      continue
    }
    let name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
    let seconds = Double(text[secondsRange]) ?? 0
    if !name.isEmpty {
      entries.append(TimingEntry(name: name, seconds: seconds))
    }
  }
  return entries
}
