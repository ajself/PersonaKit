import Foundation

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

/// Formats build-compare metrics for human review.
package enum BuildCompareReportFormatter {
  /// Render a Markdown section for a build-compare report.
  package static func appendSection(to lines: inout [String], report: BuildCompareReport) {
    lines.append("## Build Compare")
    lines.append("- Base: \(report.run.baseSha)")
    lines.append("- Head: \(report.run.headSha)")
    lines.append("- Scheme: \(report.run.scheme) | Configuration: \(report.run.configuration)")
    lines.append(
      "- App build recipes: base=\(report.base.app.buildRecipe), head=\(report.head.app.buildRecipe)"
    )
    lines.append("- Output: \(report.run.outputRoot)")
    lines.append("- Worktrees: \(report.run.worktreeRoot)")
    lines.append("")

    appendBuildTimes(to: &lines, report: report)
    appendTestStatus(to: &lines, report: report)
    appendBinarySizes(to: &lines, report: report)
    appendWarnings(to: &lines, report: report)
    appendLogs(to: &lines, report: report)
    appendNotes(to: &lines)
  }

  private static func appendBuildTimes(to lines: inout [String], report: BuildCompareReport) {
    let base = report.base
    let head = report.head
    lines.append("### Build Times")
    lines.append("| Metric | Base (s) | Head (s) | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    lines.append(
      buildTimeLine(
        title: "App clean build",
        base: base.app.cleanBuild.durationSeconds,
        head: head.app.cleanBuild.durationSeconds
      ))
    if let baseIncr = base.app.incrementalBuild?.durationSeconds,
      let headIncr = head.app.incrementalBuild?.durationSeconds
    {
      lines.append(
        buildTimeLine(
          title: "App incremental build",
          base: baseIncr,
          head: headIncr
        ))
    }
    lines.append(
      buildTimeLine(
        title: "CLI clean build",
        base: base.cli.cleanBuild.durationSeconds,
        head: head.cli.cleanBuild.durationSeconds
      ))
    if let baseIncr = base.cli.incrementalBuild?.durationSeconds,
      let headIncr = head.cli.incrementalBuild?.durationSeconds
    {
      lines.append(
        buildTimeLine(
          title: "CLI incremental build",
          base: baseIncr,
          head: headIncr
        ))
    }
    lines.append(
      buildTimeLine(
        title: "Tests",
        base: base.tests.durationSeconds,
        head: head.tests.durationSeconds
      ))
    lines.append("")
  }

  private static func appendTestStatus(to lines: inout [String], report: BuildCompareReport) {
    lines.append("### Test Status")
    lines.append("| Metric | Base | Head |")
    lines.append("| --- | --- | --- |")
    lines.append("| Success | \(report.base.tests.success) | \(report.head.tests.success) |")
    lines.append("")
  }

  private static func appendBinarySizes(to lines: inout [String], report: BuildCompareReport) {
    lines.append("### Binary Sizes (bytes)")
    lines.append("| Binary | Base | Head | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    if let baseApp = report.base.app.binary, let headApp = report.head.app.binary {
      let delta = formatBytesDelta(headApp.sizeBytes - baseApp.sizeBytes)
      lines.append(
        "| App | \(baseApp.sizeBytes) | \(headApp.sizeBytes) | \(delta) |"
      )
    } else {
      lines.append("| App | n/a | n/a | n/a |")
    }
    for binary in report.head.cli.binaries {
      let name = binaryName(for: binary.path)
      let baseBinary = report.base.cli.binaries.first { $0.path.hasSuffix("/" + name) }
      if let baseBinary {
        let deltaBytes = binary.sizeBytes - baseBinary.sizeBytes
        lines.append(
          "| \(name) | \(baseBinary.sizeBytes) | \(binary.sizeBytes) | \(formatBytesDelta(deltaBytes)) |"
        )
      } else {
        lines.append("| \(name) | n/a | \(binary.sizeBytes) | n/a |")
      }
    }
    lines.append("")
  }

  private static func appendWarnings(to lines: inout [String], report: BuildCompareReport) {
    let base = report.base
    let head = report.head
    lines.append("### Warnings")
    lines.append("| Metric | Base | Head | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    lines.append(
      warningsLine(
        title: "App clean build",
        base: base.app.cleanBuild.warningsCount,
        head: head.app.cleanBuild.warningsCount
      ))
    if let baseIncr = base.app.incrementalBuild?.warningsCount,
      let headIncr = head.app.incrementalBuild?.warningsCount
    {
      lines.append(
        warningsLine(
          title: "App incremental build",
          base: baseIncr,
          head: headIncr
        ))
    }
    lines.append(
      warningsLine(
        title: "CLI clean build",
        base: base.cli.cleanBuild.warningsCount,
        head: head.cli.cleanBuild.warningsCount
      ))
    if let baseIncr = base.cli.incrementalBuild?.warningsCount,
      let headIncr = head.cli.incrementalBuild?.warningsCount
    {
      lines.append(
        warningsLine(
          title: "CLI incremental build",
          base: baseIncr,
          head: headIncr
        ))
    }
    lines.append(
      warningsLine(
        title: "Tests",
        base: base.tests.warningsCount,
        head: head.tests.warningsCount
      ))
    lines.append("")
  }

  private static func appendLogs(to lines: inout [String], report: BuildCompareReport) {
    lines.append("### Logs")
    lines.append("- Base logs: \(report.run.outputRoot)/logs/base")
    lines.append("- Head logs: \(report.run.outputRoot)/logs/head")
    lines.append("")
  }

  private static func appendNotes(to lines: inout [String]) {
    lines.append("### Notes")
    lines.append("- Builds are sensitive to local environment and cache state.")
    lines.append("- Timing summaries are captured in JSON for detailed inspection.")
    lines.append("")
  }

  private static func buildTimeLine(title: String, base: Double, head: Double) -> String {
    let delta = formatDelta(head - base)
    return "| \(title) | \(formatSeconds(base)) | \(formatSeconds(head)) | \(delta) |"
  }

  private static func warningsLine(title: String, base: Int, head: Int) -> String {
    let delta = head - base
    return "| \(title) | \(base) | \(head) | \(delta) |"
  }

  private static func formatSeconds(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private static func binaryName(for path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }
}
