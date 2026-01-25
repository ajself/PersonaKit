import AppOpsCore
import Testing

@Test
func markdownReportIncludesKeySections() {
  let report = makeReportWithUserPacks()
  let markdown = AppOpsReportFormatter.markdown(report: report)
  #expect(markdown.contains("# AppOps Report"))
  #expect(markdown.contains("Timestamp: 2026-01-25T00:00:00Z"))
  #expect(markdown.contains("Git SHA: abc123"))
  #expect(markdown.contains("## Environment"))
  #expect(markdown.contains("## Reload Pipeline"))
  #expect(markdown.contains("Built-ins: 0.50s"))
  #expect(markdown.contains("User packs: 0.25s"))
  #expect(markdown.contains("## Compose"))
  #expect(markdown.contains("Prompt bytes: 1200"))
  #expect(markdown.contains("## Diff"))
  #expect(markdown.contains("Added: 1"))
  #expect(markdown.contains("## Import"))
  #expect(markdown.contains("Files: 2"))
  #expect(markdown.contains("## Export"))
  #expect(markdown.contains("Bytes: 4096"))
}

@Test
func markdownReportSkipsUserPacksWhenAbsent() {
  let report = makeReportWithoutUserPacks()
  let markdown = AppOpsReportFormatter.markdown(report: report)
  #expect(markdown.contains("User packs: skipped"))
}

private let repoRoot = "/repo"
private let outputRoot = "/repo/Artifacts/appops-2026-01-25"
private let builtInPackPath = "/repo/Sources/PersonaKitResources/Resources/BuiltIn.pack.json"
private let examplePackPath = "/repo/Examples/personakit.pack.json"
private let userPacksRoot = "/Users/tester/Library/Application Support/PersonaKit/Packs"

private func makeReportWithUserPacks() -> AppOpsReport {
  AppOpsReport(
    schemaVersion: 1,
    run: makeRunMetadata(),
    environment: makeEnvironmentInfo(),
    inputs: makeInputConfig(userPacksRoot: userPacksRoot, includeUserPacks: true),
    reload: makeReloadMetrics(
      ReloadScenario(
        totalDurationSeconds: 1.5,
        builtInDurationSeconds: 0.5,
        userPacks: makeLoadMetrics(
          durationSeconds: 0.25,
          packCount: 1,
          personaCount: 1,
          diagnosticsCount: 1
        ),
        mergeDurationSeconds: 0.4,
        resolveDurationSeconds: 0.35,
        totalPacks: 2,
        totalPersonas: 3,
        diagnosticsCount: 1
      )
    ),
    compose: makeComposeMetrics(durationSeconds: 0.2, personaCount: 3, promptBytes: 1200, jsonBytes: 900),
    diff: makeDiffMetrics(
      DiffScenario(
        durationSeconds: 0.05,
        leftPersonaCount: 2,
        rightPersonaCount: 3,
        addedCount: 1,
        removedCount: 0,
        modifiedCount: 1
      )
    ),
    importMetrics: makeImportMetrics(
      planDurationSeconds: 0.1,
      copyDurationSeconds: 0.2,
      filesCopied: 2,
      bytesCopied: 2048
    ),
    exportMetrics: makeExportMetrics(durationSeconds: 0.08, bytesWritten: 4096)
  )
}

private func makeReportWithoutUserPacks() -> AppOpsReport {
  AppOpsReport(
    schemaVersion: 1,
    run: makeRunMetadata(),
    environment: makeEnvironmentInfo(),
    inputs: makeInputConfig(userPacksRoot: nil, includeUserPacks: false),
    reload: makeReloadMetrics(
      ReloadScenario(
        totalDurationSeconds: 0.9,
        builtInDurationSeconds: 0.6,
        userPacks: nil,
        mergeDurationSeconds: 0.2,
        resolveDurationSeconds: 0.1,
        totalPacks: 1,
        totalPersonas: 2,
        diagnosticsCount: 0
      )
    ),
    compose: makeComposeMetrics(durationSeconds: 0.1, personaCount: 2, promptBytes: 800, jsonBytes: 600),
    diff: makeDiffMetrics(
      DiffScenario(
        durationSeconds: 0.05,
        leftPersonaCount: 2,
        rightPersonaCount: 2,
        addedCount: 0,
        removedCount: 0,
        modifiedCount: 0
      )
    ),
    importMetrics: makeImportMetrics(
      planDurationSeconds: 0.05,
      copyDurationSeconds: 0.1,
      filesCopied: 1,
      bytesCopied: 1024
    ),
    exportMetrics: makeExportMetrics(durationSeconds: 0.04, bytesWritten: 2048)
  )
}

private func makeRunMetadata() -> RunMetadata {
  RunMetadata(
    timestampUTC: "2026-01-25T00:00:00Z",
    repoRoot: repoRoot,
    outputRoot: outputRoot,
    gitSha: "abc123"
  )
}

private func makeEnvironmentInfo() -> EnvironmentInfo {
  EnvironmentInfo(
    macOSVersion: "macOS 26.0",
    swiftVersion: "Swift 6.2",
    xcodeVersion: "Xcode 16.0"
  )
}

private func makeInputConfig(userPacksRoot: String?, includeUserPacks: Bool) -> InputConfig {
  InputConfig(
    builtInSources: [builtInPackPath],
    userPacksRoot: userPacksRoot,
    includeUserPacks: includeUserPacks,
    importSource: examplePackPath,
    diffLeft: builtInPackPath,
    diffRight: examplePackPath
  )
}

private func makeReloadMetrics(_ scenario: ReloadScenario) -> ReloadMetrics {
  ReloadMetrics(
    totalDurationSeconds: scenario.totalDurationSeconds,
    builtIn: makeLoadMetrics(
      durationSeconds: scenario.builtInDurationSeconds,
      packCount: 1,
      personaCount: 2,
      diagnosticsCount: 0
    ),
    userPacks: scenario.userPacks,
    merge: MergeMetrics(
      durationSeconds: scenario.mergeDurationSeconds,
      personaCount: scenario.totalPersonas,
      diagnosticsCount: 0
    ),
    resolve: ResolveMetrics(
      durationSeconds: scenario.resolveDurationSeconds,
      personaCount: scenario.totalPersonas,
      diagnosticsCount: 0
    ),
    totalPacks: scenario.totalPacks,
    totalPersonas: scenario.totalPersonas,
    diagnosticsCount: scenario.diagnosticsCount
  )
}

private func makeLoadMetrics(
  durationSeconds: Double,
  packCount: Int,
  personaCount: Int,
  diagnosticsCount: Int
) -> LoadMetrics {
  LoadMetrics(
    durationSeconds: durationSeconds,
    packCount: packCount,
    personaCount: personaCount,
    diagnosticsCount: diagnosticsCount
  )
}

private func makeComposeMetrics(
  durationSeconds: Double,
  personaCount: Int,
  promptBytes: Int,
  jsonBytes: Int
) -> ComposeMetrics {
  ComposeMetrics(
    durationSeconds: durationSeconds,
    personaCount: personaCount,
    promptBytesTotal: promptBytes,
    jsonBytesTotal: jsonBytes
  )
}

private func makeDiffMetrics(_ scenario: DiffScenario) -> DiffMetrics {
  DiffMetrics(
    durationSeconds: scenario.durationSeconds,
    leftPersonaCount: scenario.leftPersonaCount,
    rightPersonaCount: scenario.rightPersonaCount,
    addedCount: scenario.addedCount,
    removedCount: scenario.removedCount,
    modifiedCount: scenario.modifiedCount
  )
}

private func makeImportMetrics(
  planDurationSeconds: Double,
  copyDurationSeconds: Double,
  filesCopied: Int,
  bytesCopied: Int
) -> ImportMetrics {
  ImportMetrics(
    planDurationSeconds: planDurationSeconds,
    copyDurationSeconds: copyDurationSeconds,
    filesCopied: filesCopied,
    bytesCopied: bytesCopied,
    destinationRoot: "\(outputRoot)/import/Example"
  )
}

private func makeExportMetrics(durationSeconds: Double, bytesWritten: Int) -> ExportMetrics {
  ExportMetrics(
    durationSeconds: durationSeconds,
    bytesWritten: bytesWritten,
    outputPath: "\(outputRoot)/export/Example.pack.json"
  )
}

private struct ReloadScenario {
  let totalDurationSeconds: Double
  let builtInDurationSeconds: Double
  let userPacks: LoadMetrics?
  let mergeDurationSeconds: Double
  let resolveDurationSeconds: Double
  let totalPacks: Int
  let totalPersonas: Int
  let diagnosticsCount: Int
}

private struct DiffScenario {
  let durationSeconds: Double
  let leftPersonaCount: Int
  let rightPersonaCount: Int
  let addedCount: Int
  let removedCount: Int
  let modifiedCount: Int
}
