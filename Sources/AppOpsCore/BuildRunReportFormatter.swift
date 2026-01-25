import Foundation

/// Formats build-run metrics for human review.
package enum BuildRunReportFormatter {
  /// Render a Markdown section for a build-run report.
  package static func appendSection(to lines: inout [String], report: BuildRunReport) {
    lines.append("## Build Run")
    lines.append("- Revision: \(report.run.revisionSha)")
    if let worktreePath = report.run.worktreePath {
      lines.append("- Worktree: \(worktreePath)")
    } else {
      lines.append("- Worktree: current working tree")
    }
    lines.append("- Scheme: \(report.run.scheme) | Configuration: \(report.run.configuration)")
    lines.append("- App build recipe: \(report.metrics.app.buildRecipe)")
    lines.append("- Output: \(report.run.outputRoot)")
    lines.append("")

    appendBuildTimes(to: &lines, report: report)
    appendTestStatus(to: &lines, report: report)
    appendBinarySizes(to: &lines, report: report)
    appendWarnings(to: &lines, report: report)
    appendFailures(to: &lines, report: report)
    appendLogs(to: &lines, report: report)
    appendNotes(to: &lines)
  }

  private static func appendBuildTimes(to lines: inout [String], report: BuildRunReport) {
    let metrics = report.metrics
    lines.append("### Build Times")
    lines.append("| Metric | Duration (s) |")
    lines.append("| --- | ---: |")
    lines.append(buildTimeLine(title: "App clean build", value: metrics.app.cleanBuild.durationSeconds))
    if let incremental = metrics.app.incrementalBuild?.durationSeconds {
      lines.append(buildTimeLine(title: "App incremental build", value: incremental))
    }
    lines.append(buildTimeLine(title: "CLI clean build", value: metrics.cli.cleanBuild.durationSeconds))
    if let incremental = metrics.cli.incrementalBuild?.durationSeconds {
      lines.append(buildTimeLine(title: "CLI incremental build", value: incremental))
    }
    lines.append(buildTimeLine(title: "Tests", value: metrics.tests.durationSeconds))
    lines.append("")
  }

  private static func appendTestStatus(to lines: inout [String], report: BuildRunReport) {
    lines.append("### Test Status")
    lines.append("| Metric | Value |")
    lines.append("| --- | --- |")
    lines.append("| Success | \(report.metrics.tests.success) |")
    lines.append("")
  }

  private static func appendBinarySizes(to lines: inout [String], report: BuildRunReport) {
    lines.append("### Binary Sizes (bytes)")
    lines.append("| Binary | Size |")
    lines.append("| --- | ---: |")
    if let appBinary = report.metrics.app.binary {
      lines.append("| App | \(appBinary.sizeBytes) |")
    } else {
      lines.append("| App | n/a |")
    }
    for binary in report.metrics.cli.binaries {
      let name = binaryName(for: binary.path)
      lines.append("| \(name) | \(binary.sizeBytes) |")
    }
    lines.append("")
  }

  private static func appendWarnings(to lines: inout [String], report: BuildRunReport) {
    let metrics = report.metrics
    lines.append("### Warnings")
    lines.append("| Metric | Warnings |")
    lines.append("| --- | ---: |")
    lines.append(warningsLine(title: "App clean build", value: metrics.app.cleanBuild.warningsCount))
    if let incremental = metrics.app.incrementalBuild?.warningsCount {
      lines.append(warningsLine(title: "App incremental build", value: incremental))
    }
    lines.append(warningsLine(title: "CLI clean build", value: metrics.cli.cleanBuild.warningsCount))
    if let incremental = metrics.cli.incrementalBuild?.warningsCount {
      lines.append(warningsLine(title: "CLI incremental build", value: incremental))
    }
    lines.append(warningsLine(title: "Tests", value: metrics.tests.warningsCount))
    lines.append("")
  }

  private static func appendFailures(to lines: inout [String], report: BuildRunReport) {
    let failures = failures(for: report.metrics)
    guard !failures.isEmpty else { return }
    lines.append("### Failures")
    lines.append("| Step | Description | Details | Log |")
    lines.append("| --- | --- | --- | --- |")
    for failure in failures {
      lines.append(
        "| \(escapeTable(failure.step)) | \(escapeTable(failure.description)) | \(failure.detailsPath) | \(failure.logPath) |"
      )
    }
    lines.append("")
  }

  private static func appendLogs(to lines: inout [String], report: BuildRunReport) {
    lines.append("### Logs")
    lines.append("- Logs: \(report.run.outputRoot)/logs/run")
    lines.append("")
  }

  private static func appendNotes(to lines: inout [String]) {
    lines.append("### Notes")
    lines.append("- Builds are sensitive to local environment and cache state.")
    lines.append("- Timing summaries are captured in JSON for detailed inspection.")
    lines.append("")
  }

  private static func buildTimeLine(title: String, value: Double) -> String {
    "| \(title) | \(formatSeconds(value)) |"
  }

  private static func warningsLine(title: String, value: Int) -> String {
    "| \(title) | \(value) |"
  }

  private static func formatSeconds(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private static func binaryName(for path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }

  private static func escapeTable(_ value: String) -> String {
    value.replacingOccurrences(of: "|", with: "\\|")
  }

  private static func failures(for metrics: BuildRunMetrics) -> [BuildRunFailure] {
    var failures: [BuildRunFailure] = []
    if let failure = metrics.app.cleanBuild.failure {
      failures.append(failure)
    }
    if let failure = metrics.app.incrementalBuild?.failure {
      failures.append(failure)
    }
    if let failure = metrics.cli.cleanBuild.failure {
      failures.append(failure)
    }
    if let failure = metrics.cli.incrementalBuild?.failure {
      failures.append(failure)
    }
    if let failure = metrics.tests.failure {
      failures.append(failure)
    }
    return failures
  }
}
