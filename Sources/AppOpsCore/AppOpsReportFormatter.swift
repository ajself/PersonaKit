import Foundation

/// Formats AppOps reports for human review.
package enum AppOpsReportFormatter {
  /// Render a Markdown summary for quick inspection.
  package static func markdown(report: AppOpsReport) -> String {
    var lines: [String] = []
    appendHeader(to: &lines, report: report)
    appendEnvironment(to: &lines, report: report)
    appendReload(to: &lines, report: report)
    appendCompose(to: &lines, report: report)
    appendDiff(to: &lines, report: report)
    appendImport(to: &lines, report: report)
    appendExport(to: &lines, report: report)
    return lines.joined(separator: "\n")
  }

  private static func appendHeader(to lines: inout [String], report: AppOpsReport) {
    lines.append("# AppOps Report")
    lines.append("")
    lines.append("Timestamp: \(report.run.timestampUTC)")
    lines.append("Git SHA: \(report.run.gitSha)")
    lines.append("Repo: \(report.run.repoRoot)")
    lines.append("Output: \(report.run.outputRoot)")
    lines.append("")
  }

  private static func appendEnvironment(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Environment")
    lines.append("- macOS: \(report.environment.macOSVersion)")
    lines.append("- Swift: \(report.environment.swiftVersion)")
    lines.append("- Xcode: \(report.environment.xcodeVersion)")
    lines.append("")
  }

  private static func appendReload(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Reload Pipeline")
    lines.append(
      "- Total: \(formatSeconds(report.reload.totalDurationSeconds)) | Packs: \(report.reload.totalPacks) | Personas: \(report.reload.totalPersonas) | Diagnostics: \(report.reload.diagnosticsCount)"
    )
    lines.append(
      "- Built-ins: \(formatSeconds(report.reload.builtIn.durationSeconds)) | Packs: \(report.reload.builtIn.packCount) | Personas: \(report.reload.builtIn.personaCount) | Diagnostics: \(report.reload.builtIn.diagnosticsCount)"
    )
    if let user = report.reload.userPacks {
      lines.append(
        "- User packs: \(formatSeconds(user.durationSeconds)) | Packs: \(user.packCount) | Personas: \(user.personaCount) | Diagnostics: \(user.diagnosticsCount)"
      )
    } else {
      lines.append("- User packs: skipped")
    }
    lines.append(
      "- Merge: \(formatSeconds(report.reload.merge.durationSeconds)) | Personas: \(report.reload.merge.personaCount) | Diagnostics: \(report.reload.merge.diagnosticsCount)"
    )
    lines.append(
      "- Resolve: \(formatSeconds(report.reload.resolve.durationSeconds)) | Personas: \(report.reload.resolve.personaCount) | Diagnostics: \(report.reload.resolve.diagnosticsCount)"
    )
    lines.append("")
  }

  private static func appendCompose(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Compose")
    lines.append(
      "- Duration: \(formatSeconds(report.compose.durationSeconds)) | Personas: \(report.compose.personaCount) | Prompt bytes: \(report.compose.promptBytesTotal) | JSON bytes: \(report.compose.jsonBytesTotal)"
    )
    lines.append("")
  }

  private static func appendDiff(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Diff")
    lines.append(
      "- Duration: \(formatSeconds(report.diff.durationSeconds)) | Left personas: \(report.diff.leftPersonaCount) | Right personas: \(report.diff.rightPersonaCount)"
    )
    lines.append(
      "- Added: \(report.diff.addedCount) | Removed: \(report.diff.removedCount) | Modified: \(report.diff.modifiedCount)"
    )
    lines.append("")
  }

  private static func appendImport(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Import")
    lines.append(
      "- Plan: \(formatSeconds(report.importMetrics.planDurationSeconds)) | Copy: \(formatSeconds(report.importMetrics.copyDurationSeconds))"
    )
    lines.append(
      "- Files: \(report.importMetrics.filesCopied) | Bytes: \(report.importMetrics.bytesCopied) | Destination: \(report.importMetrics.destinationRoot)"
    )
    lines.append("")
  }

  private static func appendExport(to lines: inout [String], report: AppOpsReport) {
    lines.append("## Export")
    lines.append(
      "- Duration: \(formatSeconds(report.exportMetrics.durationSeconds)) | Bytes: \(report.exportMetrics.bytesWritten) | Output: \(report.exportMetrics.outputPath)"
    )
  }

  private static func formatSeconds(_ value: Double) -> String {
    String(format: "%.2fs", value)
  }
}
