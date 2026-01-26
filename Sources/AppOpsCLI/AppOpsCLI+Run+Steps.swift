import AppOpsCore
import Foundation
import Logging
import PersonaKitCore

extension AppOpsCLI {
  private static func configureLogger(
    parsed: ParsedArgs,
    arguments: [String]
  ) throws -> Logger {
    let logLevel = try AppOpsLog.resolveLevel(parsed.value(for: "log-level"))
    AppOpsLog.configure(level: logLevel)
    let logger = AppOpsLog.logger
    logger.info("AppOps starting.")
    logger.debug("Arguments: \(arguments.joined(separator: " "))")
    return logger
  }

  private static func logInputs(
    logger: Logger,
    inputs: RunInputs
  ) {
    logger.info("Inputs resolved.")
    logger.debug("Output root: \(inputs.outputRoot.path)")
    logger.debug("Built-in packs: \(inputs.builtInURLs.count)")
    logger.debug("Include user packs: \(inputs.includeUserPacks)")
    logger.debug("Import source: \(inputs.importSource.path)")
    logger.debug("Diff left: \(inputs.diffLeft.path)")
    logger.debug("Diff right: \(inputs.diffRight.path)")
  }

  private static func runReloadStep(
    inputs: RunInputs,
    fileClient: FileClient,
    logger: Logger
  ) throws -> ReloadSnapshot {
    logger.info("Reload: starting.")
    let snapshot = try runReload(
      repoRoot: inputs.repoRoot,
      builtInURLs: inputs.builtInURLs,
      includeUserPacks: inputs.includeUserPacks,
      fileClient: fileClient
    )
    logReloadMetrics(logger: logger, metrics: snapshot.metrics)
    return snapshot
  }

  private static func runComposeStep(
    reloadSnapshot: ReloadSnapshot,
    logger: Logger
  ) -> ComposeMetrics {
    logger.info("Compose: starting.")
    let metrics = measureCompose(resolved: reloadSnapshot.resolved)
    logComposeMetrics(logger: logger, metrics: metrics)
    return metrics
  }

  private static func runDiffStep(
    inputs: RunInputs,
    logger: Logger
  ) throws -> DiffMetrics {
    logger.info("Diff: starting.")
    let metrics = try measureDiff(left: inputs.diffLeft, right: inputs.diffRight)
    logDiffMetrics(logger: logger, metrics: metrics)
    return metrics
  }

  private static func runImportStep(
    inputs: RunInputs,
    fileClient: FileClient,
    logger: Logger
  ) throws -> ImportMetrics {
    logger.info("Import: starting.")
    let metrics = try measureImport(
      selection: inputs.importSource,
      destinationRoot: inputs.outputRoot.appendingPathComponent("import", isDirectory: true),
      fileClient: fileClient
    )
    logImportMetrics(logger: logger, metrics: metrics)
    return metrics
  }

  private static func runExportStep(
    inputs: RunInputs,
    reloadSnapshot: ReloadSnapshot,
    fileClient: FileClient,
    logger: Logger
  ) throws -> ExportMetrics {
    logger.info("Export: starting.")
    let metrics = try measureExport(
      sets: reloadSnapshot.builtInSets + reloadSnapshot.userSets,
      outputRoot: inputs.outputRoot.appendingPathComponent("export", isDirectory: true),
      fileClient: fileClient
    )
    logExportMetrics(logger: logger, metrics: metrics)
    return metrics
  }

  private static func runBuildRunStep(
    inputs: RunInputs,
    environment: AppOpsEnvironment,
    logger: Logger
  ) throws -> BuildRunReport? {
    guard let buildInputs = inputs.buildRun else {
      if let reason = inputs.buildRunSkippedReason {
        logger.info("Build run: skipped (\(reason)).")
      }
      return nil
    }
    logger.info("Build run: starting.")
    let report = try runBuildRun(
      inputs: buildInputs,
      repoRoot: inputs.repoRoot,
      environment: environment
    )
    logger.info("Build run: finished.")
    return report
  }

  private static func writeReportStep(
    inputs: RunInputs,
    report: AppOpsReport,
    fileClient: FileClient,
    logger: Logger
  ) throws {
    let jsonURL = inputs.outputRoot.appendingPathComponent("report.json")
    let markdownURL = inputs.outputRoot.appendingPathComponent("REPORT.md")
    logger.info("Report: writing output.")
    try writeReport(report, jsonURL: jsonURL, markdownURL: markdownURL, fileClient: fileClient)
    print("Report written to:")
    print("- \(markdownURL.path)")
    print("- \(jsonURL.path)")
  }

  private static func logReloadMetrics(
    logger: Logger,
    metrics: ReloadMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(metrics.totalDurationSeconds)
    logger.info("Reload: finished in \(duration)s.")
    logger.debug(
      "Reload: packs \(metrics.totalPacks), personas \(metrics.totalPersonas), diag \(metrics.diagnosticsCount)."
    )
  }

  private static func logComposeMetrics(
    logger: Logger,
    metrics: ComposeMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
    let personas = metrics.personaCount
    let promptBytes = metrics.promptBytesTotal
    let jsonBytes = metrics.jsonBytesTotal
    logger.info("Compose: finished in \(duration)s.")
    logger.debug("Compose: personas \(personas), prompt \(promptBytes)B, json \(jsonBytes)B.")
  }

  private static func logDiffMetrics(
    logger: Logger,
    metrics: DiffMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
    let added = metrics.addedCount
    let removed = metrics.removedCount
    let modified = metrics.modifiedCount
    logger.info("Diff: finished in \(duration)s.")
    logger.debug("Diff: added \(added), removed \(removed), modified \(modified).")
  }

  private static func logImportMetrics(
    logger: Logger,
    metrics: ImportMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(
      metrics.planDurationSeconds + metrics.copyDurationSeconds
    )
    logger.info("Import: finished in \(duration)s.")
    logger.debug("Import: files \(metrics.filesCopied), bytes \(metrics.bytesCopied).")
  }

  private static func logExportMetrics(
    logger: Logger,
    metrics: ExportMetrics
  ) {
    let duration = AppOpsLog.formatSeconds(metrics.durationSeconds)
    logger.info("Export: finished in \(duration)s.")
    logger.debug("Export: bytes \(metrics.bytesWritten).")
  }
}
