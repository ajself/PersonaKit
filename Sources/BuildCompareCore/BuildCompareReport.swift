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

/// Generates a markdown report comparing two revisions.
package func markdownReport(
  base: RevisionMetrics,
  head: RevisionMetrics,
  metadata: RunMetadata
) -> String {
  MarkdownReportBuilder(base: base, head: head, metadata: metadata).render()
}

private struct MarkdownReportBuilder {
  let base: RevisionMetrics
  let head: RevisionMetrics
  let metadata: RunMetadata

  func render() -> String {
    var lines: [String] = []
    appendHeader(to: &lines)
    appendBuildTimes(to: &lines)
    appendTestStatus(to: &lines)
    appendBinarySizes(to: &lines)
    appendWarnings(to: &lines)
    appendLogs(to: &lines)
    appendNotes(to: &lines)
    return lines.joined(separator: "\n")
  }

  private func appendHeader(to lines: inout [String]) {
    lines.append("# Build Compare Report")
    lines.append("")
    lines.append("Base: \(metadata.baseSha)")
    lines.append("Head: \(metadata.headSha)")
    lines.append("Configuration: \(metadata.configuration)")
    lines.append("App build recipes: base=\(base.app.buildRecipe), head=\(head.app.buildRecipe)")
    lines.append("")
  }

  private func appendBuildTimes(to lines: inout [String]) {
    lines.append("## Build Times")
    lines.append("| Metric | Base (s) | Head (s) | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    lines.append(
      buildTimeLine(
        title: "App clean build",
        base: base.app.cleanBuild.durationSeconds,
        head: head.app.cleanBuild.durationSeconds
      ))
    if let baseIncr = base.app.incrementalBuild?.durationSeconds {
      if let headIncr = head.app.incrementalBuild?.durationSeconds {
        lines.append(
          buildTimeLine(
            title: "App incremental build",
            base: baseIncr,
            head: headIncr
          ))
      }
    }
    lines.append(
      buildTimeLine(
        title: "CLI clean build",
        base: base.cli.cleanBuild.durationSeconds,
        head: head.cli.cleanBuild.durationSeconds
      ))
    if let baseIncr = base.cli.incrementalBuild?.durationSeconds {
      if let headIncr = head.cli.incrementalBuild?.durationSeconds {
        lines.append(
          buildTimeLine(
            title: "CLI incremental build",
            base: baseIncr,
            head: headIncr
          ))
      }
    }
    lines.append(
      buildTimeLine(
        title: "Tests",
        base: base.tests.durationSeconds,
        head: head.tests.durationSeconds
      ))
    lines.append("")
  }

  private func appendTestStatus(to lines: inout [String]) {
    lines.append("## Test Status")
    lines.append("| Metric | Base | Head |")
    lines.append("| --- | --- | --- |")
    lines.append("| Success | \(base.tests.success) | \(head.tests.success) |")
    lines.append("")
  }

  private func appendBinarySizes(to lines: inout [String]) {
    lines.append("## Binary Sizes (bytes)")
    lines.append("| Binary | Base | Head | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    if let baseApp = base.app.binary, let headApp = head.app.binary {
      let delta = formatBytesDelta(headApp.sizeBytes - baseApp.sizeBytes)
      lines.append(
        "| App | \(baseApp.sizeBytes) | \(headApp.sizeBytes) | \(delta) |"
      )
    } else {
      lines.append("| App | n/a | n/a | n/a |")
    }
    for binary in head.cli.binaries {
      let name = binaryName(for: binary.path)
      let baseBinary = base.cli.binaries.first {
        $0.path.hasSuffix("/" + name)
      }
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

  private func appendWarnings(to lines: inout [String]) {
    lines.append("## Warnings")
    lines.append("| Metric | Base | Head | Delta |")
    lines.append("| --- | ---: | ---: | ---: |")
    lines.append(
      warningsLine(
        title: "App clean build",
        base: base.app.cleanBuild.warningsCount,
        head: head.app.cleanBuild.warningsCount
      ))
    if let baseIncr = base.app.incrementalBuild?.warningsCount {
      if let headIncr = head.app.incrementalBuild?.warningsCount {
        lines.append(
          warningsLine(
            title: "App incremental build",
            base: baseIncr,
            head: headIncr
          ))
      }
    }
    lines.append(
      warningsLine(
        title: "CLI clean build",
        base: base.cli.cleanBuild.warningsCount,
        head: head.cli.cleanBuild.warningsCount
      ))
    if let baseIncr = base.cli.incrementalBuild?.warningsCount {
      if let headIncr = head.cli.incrementalBuild?.warningsCount {
        lines.append(
          warningsLine(
            title: "CLI incremental build",
            base: baseIncr,
            head: headIncr
          ))
      }
    }
    lines.append(
      warningsLine(
        title: "Tests",
        base: base.tests.warningsCount,
        head: head.tests.warningsCount
      ))
    lines.append("")
  }

  private func appendLogs(to lines: inout [String]) {
    lines.append("## Logs")
    lines.append("- Base logs: \(metadata.outputRoot)/logs/base")
    lines.append("- Head logs: \(metadata.outputRoot)/logs/head")
    lines.append("")
  }

  private func appendNotes(to lines: inout [String]) {
    lines.append("## Notes")
    lines.append("- Builds are sensitive to local environment and cache state.")
    lines.append("- Timing summaries are captured in JSON for detailed inspection.")
  }

  private func buildTimeLine(title: String, base: Double, head: Double) -> String {
    let delta = formatDelta(head - base)
    return "| \(title) | \(formatSeconds(base)) | \(formatSeconds(head)) | \(delta) |"
  }

  private func warningsLine(title: String, base: Int, head: Int) -> String {
    let delta = head - base
    return "| \(title) | \(base) | \(head) | \(delta) |"
  }

  private func formatSeconds(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private func binaryName(for path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }
}
