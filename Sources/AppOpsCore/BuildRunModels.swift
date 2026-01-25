import Foundation

/// Recorded failure details for a build or test step.
package struct BuildRunFailure: Codable, Equatable, Sendable {
  package let step: String
  package let description: String
  package let logPath: String
  package let detailsPath: String

  package init(
    step: String,
    description: String,
    logPath: String,
    detailsPath: String
  ) {
    self.step = step
    self.description = description
    self.logPath = logPath
    self.detailsPath = detailsPath
  }

  package enum CodingKeys: String, CodingKey {
    case step
    case description
    case logPath = "log_path"
    case detailsPath = "details_path"
  }
}

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
  package let failure: BuildRunFailure?

  package init(
    durationSeconds: Double,
    warningsCount: Int,
    timingSummary: [TimingEntry]?,
    logPath: String,
    outputPath: String?,
    failure: BuildRunFailure? = nil
  ) {
    self.durationSeconds = durationSeconds
    self.warningsCount = warningsCount
    self.timingSummary = timingSummary
    self.logPath = logPath
    self.outputPath = outputPath
    self.failure = failure
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case warningsCount = "warnings_count"
    case timingSummary = "timing_summary"
    case logPath = "log_path"
    case outputPath = "output_path"
    case failure
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
  package let failure: BuildRunFailure?

  package init(
    durationSeconds: Double,
    warningsCount: Int,
    success: Bool,
    logPath: String,
    failure: BuildRunFailure? = nil
  ) {
    self.durationSeconds = durationSeconds
    self.warningsCount = warningsCount
    self.success = success
    self.logPath = logPath
    self.failure = failure
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case warningsCount = "warnings_count"
    case success
    case logPath = "log_path"
    case failure
  }
}

/// Metrics captured for a single git revision.
package struct BuildRunMetrics: Codable, Equatable, Sendable {
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

/// Metadata that describes the environment and inputs for a build run.
package struct BuildRunMetadata: Codable, Equatable, Sendable {
  package let timestampUTC: String
  package let repoRoot: String
  package let revisionSha: String
  package let worktreePath: String?
  package let outputRoot: String
  package let scheme: String
  package let configuration: String
  package let swiftVersion: String
  package let xcodeVersion: String

  package init(
    timestampUTC: String,
    repoRoot: String,
    revisionSha: String,
    worktreePath: String?,
    outputRoot: String,
    scheme: String,
    configuration: String,
    swiftVersion: String,
    xcodeVersion: String
  ) {
    self.timestampUTC = timestampUTC
    self.repoRoot = repoRoot
    self.revisionSha = revisionSha
    self.worktreePath = worktreePath
    self.outputRoot = outputRoot
    self.scheme = scheme
    self.configuration = configuration
    self.swiftVersion = swiftVersion
    self.xcodeVersion = xcodeVersion
  }

  package enum CodingKeys: String, CodingKey {
    case timestampUTC = "timestamp_utc"
    case repoRoot = "repo_root"
    case revisionSha = "revision_sha"
    case worktreePath = "worktree_path"
    case outputRoot = "output_root"
    case scheme
    case configuration
    case swiftVersion = "swift_version"
    case xcodeVersion = "xcode_version"
  }
}

/// The build-run report schema embedded in AppOps output.
package struct BuildRunReport: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let run: BuildRunMetadata
  package let metrics: BuildRunMetrics

  package init(
    schemaVersion: Int,
    run: BuildRunMetadata,
    metrics: BuildRunMetrics
  ) {
    self.schemaVersion = schemaVersion
    self.run = run
    self.metrics = metrics
  }

  package enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case run
    case metrics
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

/// Configuration file schema for build-run app recipes.
package struct BuildRunConfig: Codable, Equatable, Sendable {
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
