import AppOpsCore
import Testing

@Test
func markdownReportIncludesKeySections() {
  let report = AppOpsReport(
    schemaVersion: 1,
    run: RunMetadata(
      timestampUTC: "2026-01-25T00:00:00Z",
      repoRoot: "/repo",
      outputRoot: "/repo/Artifacts/appops-2026-01-25",
      gitSha: "abc123"
    ),
    environment: EnvironmentInfo(
      macOSVersion: "macOS 26.0",
      swiftVersion: "Swift 6.2",
      xcodeVersion: "Xcode 16.0"
    ),
    inputs: InputConfig(
      builtInSources: ["/repo/Sources/PersonaKitResources/Resources/BuiltIn.pack.json"],
      userPacksRoot: "/Users/tester/Library/Application Support/PersonaKit/Packs",
      includeUserPacks: true,
      importSource: "/repo/Examples/personakit.pack.json",
      diffLeft: "/repo/Sources/PersonaKitResources/Resources/BuiltIn.pack.json",
      diffRight: "/repo/Examples/personakit.pack.json"
    ),
    reload: ReloadMetrics(
      totalDurationSeconds: 1.5,
      builtIn: LoadMetrics(
        durationSeconds: 0.5,
        packCount: 1,
        personaCount: 2,
        diagnosticsCount: 0
      ),
      userPacks: LoadMetrics(
        durationSeconds: 0.25,
        packCount: 1,
        personaCount: 1,
        diagnosticsCount: 1
      ),
      merge: MergeMetrics(durationSeconds: 0.4, personaCount: 3, diagnosticsCount: 0),
      resolve: ResolveMetrics(durationSeconds: 0.35, personaCount: 3, diagnosticsCount: 0),
      totalPacks: 2,
      totalPersonas: 3,
      diagnosticsCount: 1
    ),
    compose: ComposeMetrics(
      durationSeconds: 0.2,
      personaCount: 3,
      promptBytesTotal: 1200,
      jsonBytesTotal: 900
    ),
    diff: DiffMetrics(
      durationSeconds: 0.05,
      leftPersonaCount: 2,
      rightPersonaCount: 3,
      addedCount: 1,
      removedCount: 0,
      modifiedCount: 1
    ),
    importMetrics: ImportMetrics(
      planDurationSeconds: 0.1,
      copyDurationSeconds: 0.2,
      filesCopied: 2,
      bytesCopied: 2048,
      destinationRoot: "/repo/Artifacts/appops-2026-01-25/import/Example"
    ),
    exportMetrics: ExportMetrics(
      durationSeconds: 0.08,
      bytesWritten: 4096,
      outputPath: "/repo/Artifacts/appops-2026-01-25/export/Example.pack.json"
    )
  )

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
  let report = AppOpsReport(
    schemaVersion: 1,
    run: RunMetadata(
      timestampUTC: "2026-01-25T00:00:00Z",
      repoRoot: "/repo",
      outputRoot: "/repo/Artifacts/appops-2026-01-25",
      gitSha: "abc123"
    ),
    environment: EnvironmentInfo(
      macOSVersion: "macOS 26.0",
      swiftVersion: "Swift 6.2",
      xcodeVersion: "Xcode 16.0"
    ),
    inputs: InputConfig(
      builtInSources: ["/repo/Sources/PersonaKitResources/Resources/BuiltIn.pack.json"],
      userPacksRoot: nil,
      includeUserPacks: false,
      importSource: "/repo/Examples/personakit.pack.json",
      diffLeft: "/repo/Sources/PersonaKitResources/Resources/BuiltIn.pack.json",
      diffRight: "/repo/Examples/personakit.pack.json"
    ),
    reload: ReloadMetrics(
      totalDurationSeconds: 0.9,
      builtIn: LoadMetrics(
        durationSeconds: 0.6,
        packCount: 1,
        personaCount: 2,
        diagnosticsCount: 0
      ),
      userPacks: nil,
      merge: MergeMetrics(durationSeconds: 0.2, personaCount: 2, diagnosticsCount: 0),
      resolve: ResolveMetrics(durationSeconds: 0.1, personaCount: 2, diagnosticsCount: 0),
      totalPacks: 1,
      totalPersonas: 2,
      diagnosticsCount: 0
    ),
    compose: ComposeMetrics(
      durationSeconds: 0.1,
      personaCount: 2,
      promptBytesTotal: 800,
      jsonBytesTotal: 600
    ),
    diff: DiffMetrics(
      durationSeconds: 0.05,
      leftPersonaCount: 2,
      rightPersonaCount: 2,
      addedCount: 0,
      removedCount: 0,
      modifiedCount: 0
    ),
    importMetrics: ImportMetrics(
      planDurationSeconds: 0.05,
      copyDurationSeconds: 0.1,
      filesCopied: 1,
      bytesCopied: 1024,
      destinationRoot: "/repo/Artifacts/appops-2026-01-25/import/Example"
    ),
    exportMetrics: ExportMetrics(
      durationSeconds: 0.04,
      bytesWritten: 2048,
      outputPath: "/repo/Artifacts/appops-2026-01-25/export/Example.pack.json"
    )
  )

  let markdown = AppOpsReportFormatter.markdown(report: report)
  #expect(markdown.contains("User packs: skipped"))
}
