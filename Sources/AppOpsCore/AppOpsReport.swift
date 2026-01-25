import Foundation

/// Top-level AppOps report emitted by the CLI.
package struct AppOpsReport: Codable, Sendable {
  package let schemaVersion: Int
  package let run: RunMetadata
  package let environment: EnvironmentInfo
  package let inputs: InputConfig
  package let reload: ReloadMetrics
  package let compose: ComposeMetrics
  package let diff: DiffMetrics
  package let importMetrics: ImportMetrics
  package let exportMetrics: ExportMetrics
  package let buildRun: BuildRunReport?
  package let buildRunSkippedReason: String?

  package init(
    schemaVersion: Int,
    run: RunMetadata,
    environment: EnvironmentInfo,
    inputs: InputConfig,
    reload: ReloadMetrics,
    compose: ComposeMetrics,
    diff: DiffMetrics,
    importMetrics: ImportMetrics,
    exportMetrics: ExportMetrics,
    buildRun: BuildRunReport?,
    buildRunSkippedReason: String?
  ) {
    self.schemaVersion = schemaVersion
    self.run = run
    self.environment = environment
    self.inputs = inputs
    self.reload = reload
    self.compose = compose
    self.diff = diff
    self.importMetrics = importMetrics
    self.exportMetrics = exportMetrics
    self.buildRun = buildRun
    self.buildRunSkippedReason = buildRunSkippedReason
  }

  package enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case run
    case environment
    case inputs
    case reload
    case compose
    case diff
    case importMetrics = "import"
    case exportMetrics = "export"
    case buildRun = "build_run"
    case buildRunSkippedReason = "build_run_skipped_reason"
  }
}

/// Run metadata captured for each AppOps invocation.
package struct RunMetadata: Codable, Sendable {
  package let timestampUTC: String
  package let repoRoot: String
  package let outputRoot: String
  package let gitSha: String

  package init(
    timestampUTC: String,
    repoRoot: String,
    outputRoot: String,
    gitSha: String
  ) {
    self.timestampUTC = timestampUTC
    self.repoRoot = repoRoot
    self.outputRoot = outputRoot
    self.gitSha = gitSha
  }

  package enum CodingKeys: String, CodingKey {
    case timestampUTC = "timestamp_utc"
    case repoRoot = "repo_root"
    case outputRoot = "output_root"
    case gitSha = "git_sha"
  }
}

/// Environment information recorded alongside AppOps metrics.
package struct EnvironmentInfo: Codable, Sendable {
  package let macOSVersion: String
  package let swiftVersion: String
  package let xcodeVersion: String

  package init(
    macOSVersion: String,
    swiftVersion: String,
    xcodeVersion: String
  ) {
    self.macOSVersion = macOSVersion
    self.swiftVersion = swiftVersion
    self.xcodeVersion = xcodeVersion
  }

  package enum CodingKeys: String, CodingKey {
    case macOSVersion = "macos_version"
    case swiftVersion = "swift_version"
    case xcodeVersion = "xcode_version"
  }
}

/// Inputs that influence the AppOps run and report output.
package struct InputConfig: Codable, Sendable {
  package let builtInSources: [String]
  package let userPacksRoot: String?
  package let includeUserPacks: Bool
  package let importSource: String
  package let diffLeft: String
  package let diffRight: String

  package init(
    builtInSources: [String],
    userPacksRoot: String?,
    includeUserPacks: Bool,
    importSource: String,
    diffLeft: String,
    diffRight: String
  ) {
    self.builtInSources = builtInSources
    self.userPacksRoot = userPacksRoot
    self.includeUserPacks = includeUserPacks
    self.importSource = importSource
    self.diffLeft = diffLeft
    self.diffRight = diffRight
  }

  package enum CodingKeys: String, CodingKey {
    case builtInSources = "built_in_sources"
    case userPacksRoot = "user_packs_root"
    case includeUserPacks = "include_user_packs"
    case importSource = "import_source"
    case diffLeft = "diff_left"
    case diffRight = "diff_right"
  }
}

/// Summary metrics for reload and resolver pipeline work.
package struct ReloadMetrics: Codable, Sendable {
  package let totalDurationSeconds: Double
  package let builtIn: LoadMetrics
  package let userPacks: LoadMetrics?
  package let merge: MergeMetrics
  package let resolve: ResolveMetrics
  package let totalPacks: Int
  package let totalPersonas: Int
  package let diagnosticsCount: Int

  package init(
    totalDurationSeconds: Double,
    builtIn: LoadMetrics,
    userPacks: LoadMetrics?,
    merge: MergeMetrics,
    resolve: ResolveMetrics,
    totalPacks: Int,
    totalPersonas: Int,
    diagnosticsCount: Int
  ) {
    self.totalDurationSeconds = totalDurationSeconds
    self.builtIn = builtIn
    self.userPacks = userPacks
    self.merge = merge
    self.resolve = resolve
    self.totalPacks = totalPacks
    self.totalPersonas = totalPersonas
    self.diagnosticsCount = diagnosticsCount
  }

  package enum CodingKeys: String, CodingKey {
    case totalDurationSeconds = "total_duration_seconds"
    case builtIn = "built_in"
    case userPacks = "user_packs"
    case merge
    case resolve
    case totalPacks = "total_packs"
    case totalPersonas = "total_personas"
    case diagnosticsCount = "diagnostics_count"
  }
}

/// Metrics emitted for a single pack load step.
package struct LoadMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let packCount: Int
  package let personaCount: Int
  package let diagnosticsCount: Int

  package init(
    durationSeconds: Double,
    packCount: Int,
    personaCount: Int,
    diagnosticsCount: Int
  ) {
    self.durationSeconds = durationSeconds
    self.packCount = packCount
    self.personaCount = personaCount
    self.diagnosticsCount = diagnosticsCount
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case packCount = "pack_count"
    case personaCount = "persona_count"
    case diagnosticsCount = "diagnostics_count"
  }
}

/// Metrics emitted for merging packs into a resolved map.
package struct MergeMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let personaCount: Int
  package let diagnosticsCount: Int

  package init(
    durationSeconds: Double,
    personaCount: Int,
    diagnosticsCount: Int
  ) {
    self.durationSeconds = durationSeconds
    self.personaCount = personaCount
    self.diagnosticsCount = diagnosticsCount
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case personaCount = "persona_count"
    case diagnosticsCount = "diagnostics_count"
  }
}

/// Metrics emitted for resolving merged personas.
package struct ResolveMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let personaCount: Int
  package let diagnosticsCount: Int

  package init(
    durationSeconds: Double,
    personaCount: Int,
    diagnosticsCount: Int
  ) {
    self.durationSeconds = durationSeconds
    self.personaCount = personaCount
    self.diagnosticsCount = diagnosticsCount
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case personaCount = "persona_count"
    case diagnosticsCount = "diagnostics_count"
  }
}

/// Metrics emitted while composing prompt + JSON output.
package struct ComposeMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let personaCount: Int
  package let promptBytesTotal: Int
  package let jsonBytesTotal: Int

  package init(
    durationSeconds: Double,
    personaCount: Int,
    promptBytesTotal: Int,
    jsonBytesTotal: Int
  ) {
    self.durationSeconds = durationSeconds
    self.personaCount = personaCount
    self.promptBytesTotal = promptBytesTotal
    self.jsonBytesTotal = jsonBytesTotal
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case personaCount = "persona_count"
    case promptBytesTotal = "prompt_bytes_total"
    case jsonBytesTotal = "json_bytes_total"
  }
}

/// Metrics emitted for diffing two pack files.
package struct DiffMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let leftPersonaCount: Int
  package let rightPersonaCount: Int
  package let addedCount: Int
  package let removedCount: Int
  package let modifiedCount: Int

  package init(
    durationSeconds: Double,
    leftPersonaCount: Int,
    rightPersonaCount: Int,
    addedCount: Int,
    removedCount: Int,
    modifiedCount: Int
  ) {
    self.durationSeconds = durationSeconds
    self.leftPersonaCount = leftPersonaCount
    self.rightPersonaCount = rightPersonaCount
    self.addedCount = addedCount
    self.removedCount = removedCount
    self.modifiedCount = modifiedCount
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case leftPersonaCount = "left_persona_count"
    case rightPersonaCount = "right_persona_count"
    case addedCount = "added_count"
    case removedCount = "removed_count"
    case modifiedCount = "modified_count"
  }
}

/// Metrics emitted while planning and copying an import.
package struct ImportMetrics: Codable, Sendable {
  package let planDurationSeconds: Double
  package let copyDurationSeconds: Double
  package let filesCopied: Int
  package let bytesCopied: Int64
  package let destinationRoot: String

  package init(
    planDurationSeconds: Double,
    copyDurationSeconds: Double,
    filesCopied: Int,
    bytesCopied: Int64,
    destinationRoot: String
  ) {
    self.planDurationSeconds = planDurationSeconds
    self.copyDurationSeconds = copyDurationSeconds
    self.filesCopied = filesCopied
    self.bytesCopied = bytesCopied
    self.destinationRoot = destinationRoot
  }

  package enum CodingKeys: String, CodingKey {
    case planDurationSeconds = "plan_duration_seconds"
    case copyDurationSeconds = "copy_duration_seconds"
    case filesCopied = "files_copied"
    case bytesCopied = "bytes_copied"
    case destinationRoot = "destination_root"
  }
}

/// Metrics emitted while exporting a pack snapshot.
package struct ExportMetrics: Codable, Sendable {
  package let durationSeconds: Double
  package let bytesWritten: Int64
  package let outputPath: String

  package init(
    durationSeconds: Double,
    bytesWritten: Int64,
    outputPath: String
  ) {
    self.durationSeconds = durationSeconds
    self.bytesWritten = bytesWritten
    self.outputPath = outputPath
  }

  package enum CodingKeys: String, CodingKey {
    case durationSeconds = "duration_seconds"
    case bytesWritten = "bytes_written"
    case outputPath = "output_path"
  }
}
