import Foundation

package struct TimingEntry: Codable, Equatable {
  package let name: String
  package let seconds: Double

  package init(name: String, seconds: Double) {
    self.name = name
    self.seconds = seconds
  }
}

package struct BuildStepMetrics: Codable, Equatable {
  package let duration_seconds: Double
  package let warnings_count: Int
  package let timing_summary: [TimingEntry]?
  package let log_path: String
  package let output_path: String?

  package init(
    duration_seconds: Double,
    warnings_count: Int,
    timing_summary: [TimingEntry]?,
    log_path: String,
    output_path: String?
  ) {
    self.duration_seconds = duration_seconds
    self.warnings_count = warnings_count
    self.timing_summary = timing_summary
    self.log_path = log_path
    self.output_path = output_path
  }
}

package struct BinaryMetric: Codable, Equatable {
  package let path: String
  package let size_bytes: Int64

  package init(path: String, size_bytes: Int64) {
    self.path = path
    self.size_bytes = size_bytes
  }
}

package struct AppMetrics: Codable, Equatable {
  package let build_recipe: String
  package let clean_build: BuildStepMetrics
  package let incremental_build: BuildStepMetrics?
  package let binary: BinaryMetric?

  package init(
    build_recipe: String,
    clean_build: BuildStepMetrics,
    incremental_build: BuildStepMetrics?,
    binary: BinaryMetric?
  ) {
    self.build_recipe = build_recipe
    self.clean_build = clean_build
    self.incremental_build = incremental_build
    self.binary = binary
  }
}

package struct CliMetrics: Codable, Equatable {
  package let clean_build: BuildStepMetrics
  package let incremental_build: BuildStepMetrics?
  package let binaries: [BinaryMetric]

  package init(
    clean_build: BuildStepMetrics,
    incremental_build: BuildStepMetrics?,
    binaries: [BinaryMetric]
  ) {
    self.clean_build = clean_build
    self.incremental_build = incremental_build
    self.binaries = binaries
  }
}

package struct TestMetrics: Codable, Equatable {
  package let duration_seconds: Double
  package let warnings_count: Int
  package let success: Bool
  package let log_path: String

  package init(
    duration_seconds: Double,
    warnings_count: Int,
    success: Bool,
    log_path: String
  ) {
    self.duration_seconds = duration_seconds
    self.warnings_count = warnings_count
    self.success = success
    self.log_path = log_path
  }
}

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

package struct RunMetadata: Codable, Equatable {
  package let timestamp_utc: String
  package let repo_root: String
  package let base_sha: String
  package let head_sha: String
  package let worktree_root: String
  package let output_root: String
  package let scheme: String
  package let configuration: String
  package let swift_version: String
  package let xcode_version: String

  package init(
    timestamp_utc: String,
    repo_root: String,
    base_sha: String,
    head_sha: String,
    worktree_root: String,
    output_root: String,
    scheme: String,
    configuration: String,
    swift_version: String,
    xcode_version: String
  ) {
    self.timestamp_utc = timestamp_utc
    self.repo_root = repo_root
    self.base_sha = base_sha
    self.head_sha = head_sha
    self.worktree_root = worktree_root
    self.output_root = output_root
    self.scheme = scheme
    self.configuration = configuration
    self.swift_version = swift_version
    self.xcode_version = xcode_version
  }
}

package struct Report: Codable, Equatable {
  package let schema_version: Int
  package let run: RunMetadata
  package let base: RevisionMetrics
  package let head: RevisionMetrics

  package init(
    schema_version: Int,
    run: RunMetadata,
    base: RevisionMetrics,
    head: RevisionMetrics
  ) {
    self.schema_version = schema_version
    self.run = run
    self.base = base
    self.head = head
  }
}

package struct AppBuildRecipe: Codable, Equatable {
  package let name: String
  package let workspace: String?
  package let scheme: String?
  package let xcodebuild_args: [String]

  package init(
    name: String,
    workspace: String?,
    scheme: String?,
    xcodebuild_args: [String]
  ) {
    self.name = name
    self.workspace = workspace
    self.scheme = scheme
    self.xcodebuild_args = xcodebuild_args
  }
}

package struct BuildCompareConfig: Codable, Equatable {
  package let schema_version: Int
  package let app_recipes: [AppBuildRecipe]

  package init(schema_version: Int, app_recipes: [AppBuildRecipe]) {
    self.schema_version = schema_version
    self.app_recipes = app_recipes
  }

  package func appRecipes(forWorkspace workspace: String) -> [AppBuildRecipe] {
    let matches = app_recipes.filter { recipe in
      guard let target = recipe.workspace else { return true }
      return target == workspace
    }
    return matches.isEmpty ? app_recipes : matches
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
       let secondsRange = Range(match.range(at: 2), in: text) {
      let name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
      let seconds = Double(text[secondsRange]) ?? 0
      if !name.isEmpty {
        entries.append(TimingEntry(name: name, seconds: seconds))
      }
    }
  }
  return entries
}

package func formatDelta(_ value: Double) -> String {
  let sign = value >= 0 ? "+" : ""
  return String(format: "%@%.2fs", sign, value)
}

package func formatBytesDelta(_ value: Int64) -> String {
  let sign = value >= 0 ? "+" : ""
  return "\(sign)\(value)"
}

package func markdownReport(base: RevisionMetrics, head: RevisionMetrics, metadata: RunMetadata) -> String {
  func delta(_ head: Double, _ base: Double) -> String {
    formatDelta(head - base)
  }

  let appCleanDelta = delta(head.app.clean_build.duration_seconds, base.app.clean_build.duration_seconds)
  let cliCleanDelta = delta(head.cli.clean_build.duration_seconds, base.cli.clean_build.duration_seconds)
  let testDelta = delta(head.tests.duration_seconds, base.tests.duration_seconds)

  var appBinaryDelta = "n/a"
  if let baseApp = base.app.binary, let headApp = head.app.binary {
    appBinaryDelta = formatBytesDelta(headApp.size_bytes - baseApp.size_bytes)
  }

  var lines: [String] = []
  lines.append("# Build Compare Report")
  lines.append("")
  lines.append("Base: \(metadata.base_sha)")
  lines.append("Head: \(metadata.head_sha)")
  lines.append("Configuration: \(metadata.configuration)")
  lines.append("App build recipes: base=\(base.app.build_recipe), head=\(head.app.build_recipe)")
  lines.append("")
  lines.append("## Build Times")
  lines.append("| Metric | Base (s) | Head (s) | Delta |")
  lines.append("| --- | ---: | ---: | ---: |")
  lines.append("| App clean build | \(String(format: "%.2f", base.app.clean_build.duration_seconds)) | \(String(format: "%.2f", head.app.clean_build.duration_seconds)) | \(appCleanDelta) |")
  if let baseIncr = base.app.incremental_build?.duration_seconds,
     let headIncr = head.app.incremental_build?.duration_seconds {
    lines.append("| App incremental build | \(String(format: "%.2f", baseIncr)) | \(String(format: "%.2f", headIncr)) | \(formatDelta(headIncr - baseIncr)) |")
  }
  lines.append("| CLI clean build | \(String(format: "%.2f", base.cli.clean_build.duration_seconds)) | \(String(format: "%.2f", head.cli.clean_build.duration_seconds)) | \(cliCleanDelta) |")
  if let baseIncr = base.cli.incremental_build?.duration_seconds,
     let headIncr = head.cli.incremental_build?.duration_seconds {
    lines.append("| CLI incremental build | \(String(format: "%.2f", baseIncr)) | \(String(format: "%.2f", headIncr)) | \(formatDelta(headIncr - baseIncr)) |")
  }
  lines.append("| Tests | \(String(format: "%.2f", base.tests.duration_seconds)) | \(String(format: "%.2f", head.tests.duration_seconds)) | \(testDelta) |")
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
    lines.append("| App | \(baseApp.size_bytes) | \(headApp.size_bytes) | \(appBinaryDelta) |")
  } else {
    lines.append("| App | n/a | n/a | n/a |")
  }
  for binary in head.cli.binaries {
    let baseBinary = base.cli.binaries.first {
      $0.path.hasSuffix("/" + URL(fileURLWithPath: binary.path).lastPathComponent)
    }
    if let baseBinary {
      let deltaBytes = binary.size_bytes - baseBinary.size_bytes
      lines.append("| \(URL(fileURLWithPath: binary.path).lastPathComponent) | \(baseBinary.size_bytes) | \(binary.size_bytes) | \(formatBytesDelta(deltaBytes)) |")
    } else {
      lines.append("| \(URL(fileURLWithPath: binary.path).lastPathComponent) | n/a | \(binary.size_bytes) | n/a |")
    }
  }
  lines.append("")
  lines.append("## Warnings")
  lines.append("| Metric | Base | Head | Delta |")
  lines.append("| --- | ---: | ---: | ---: |")
  lines.append("| App clean build | \(base.app.clean_build.warnings_count) | \(head.app.clean_build.warnings_count) | \(head.app.clean_build.warnings_count - base.app.clean_build.warnings_count) |")
  if let baseIncr = base.app.incremental_build?.warnings_count,
     let headIncr = head.app.incremental_build?.warnings_count {
    lines.append("| App incremental build | \(baseIncr) | \(headIncr) | \(headIncr - baseIncr) |")
  }
  lines.append("| CLI clean build | \(base.cli.clean_build.warnings_count) | \(head.cli.clean_build.warnings_count) | \(head.cli.clean_build.warnings_count - base.cli.clean_build.warnings_count) |")
  if let baseIncr = base.cli.incremental_build?.warnings_count,
     let headIncr = head.cli.incremental_build?.warnings_count {
    lines.append("| CLI incremental build | \(baseIncr) | \(headIncr) | \(headIncr - baseIncr) |")
  }
  lines.append("| Tests | \(base.tests.warnings_count) | \(head.tests.warnings_count) | \(head.tests.warnings_count - base.tests.warnings_count) |")
  lines.append("")
  lines.append("## Logs")
  lines.append("- Base logs: \(metadata.output_root)/logs/base")
  lines.append("- Head logs: \(metadata.output_root)/logs/head")
  lines.append("")
  lines.append("## Notes")
  lines.append("- Builds are sensitive to local environment and cache state.")
  lines.append("- Timing summaries are captured in JSON for detailed inspection.")
  return lines.joined(separator: "\n")
}
