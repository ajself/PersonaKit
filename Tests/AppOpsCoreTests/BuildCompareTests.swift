import AppOpsCore
import Testing

@Test
func countWarningsCountsLines() {
  let output = """
    warning: something
    note: informational
    warning: another
    """

  #expect(countWarnings(output) == 2)
}

@Test
func parseTimingSummaryParsesNamedEntries() {
  let output = """
      Compile Swift 1.23s
      Link 0.45s
    some other line
    """

  let entries = parseTimingSummary(output)
  #expect(entries.count == 2)
  #expect(entries[0].name == "Compile Swift")
  #expect(entries[0].seconds == 1.23)
  #expect(entries[1].name == "Link")
  #expect(entries[1].seconds == 0.45)
}

@Test
func formatDeltaAddsSignAndPrecision() {
  #expect(formatDelta(1.234) == "+1.23s")
  #expect(formatDelta(-0.5) == "-0.50s")
}

@Test
func formatBytesDeltaAddsSign() {
  #expect(formatBytesDelta(42) == "+42")
  #expect(formatBytesDelta(-7) == "-7")
}

@Test
func buildCompareSectionIncludesKeySectionsAndDeltas() {
  let baseBuild = BuildStepMetrics(
    durationSeconds: 10,
    warningsCount: 1,
    timingSummary: nil,
    logPath: "/tmp/base.log",
    outputPath: nil
  )
  let headBuild = BuildStepMetrics(
    durationSeconds: 12,
    warningsCount: 3,
    timingSummary: nil,
    logPath: "/tmp/head.log",
    outputPath: nil
  )

  let base = BuildCompareRevisionMetrics(
    sha: "base",
    app: AppMetrics(
      buildRecipe: "default", cleanBuild: baseBuild, incrementalBuild: nil, binary: nil
    ),
    cli: CliMetrics(cleanBuild: baseBuild, incrementalBuild: nil, binaries: []),
    tests: TestMetrics(
      durationSeconds: 5, warningsCount: 0, success: true, logPath: "/tmp/tests.log"
    )
  )

  let head = BuildCompareRevisionMetrics(
    sha: "head",
    app: AppMetrics(
      buildRecipe: "legacy", cleanBuild: headBuild, incrementalBuild: nil, binary: nil
    ),
    cli: CliMetrics(cleanBuild: headBuild, incrementalBuild: nil, binaries: []),
    tests: TestMetrics(
      durationSeconds: 6, warningsCount: 1, success: true, logPath: "/tmp/tests.log"
    )
  )

  let metadata = BuildCompareRunMetadata(
    timestampUTC: "2026-01-25T00:00:00Z",
    repoRoot: "/repo",
    baseSha: "base",
    headSha: "head",
    worktreeRoot: "/tmp/worktrees",
    outputRoot: "/tmp/output",
    scheme: "PersonaKitApp",
    configuration: "Release",
    swiftVersion: "Swift 6.2",
    xcodeVersion: "Xcode 16"
  )

  let report = BuildCompareReport(schemaVersion: 2, run: metadata, base: base, head: head)
  var lines: [String] = []
  BuildCompareReportFormatter.appendSection(to: &lines, report: report)
  let markdown = lines.joined(separator: "\n")

  #expect(markdown.contains("## Build Compare"))
  #expect(markdown.contains("Base: base"))
  #expect(markdown.contains("Head: head"))
  #expect(markdown.contains("App build recipes: base=default, head=legacy"))
  #expect(markdown.contains("| App clean build | 10.00 | 12.00 | +2.00s |"))
  #expect(markdown.contains("| Tests | 5.00 | 6.00 | +1.00s |"))
  #expect(markdown.contains("| Success | true | true |"))
  #expect(markdown.contains("### Warnings"))
  #expect(markdown.contains("| App clean build | 1 | 3 | 2 |"))
}

@Test
func configFiltersRecipesByWorkspace() throws {
  let recipes = [
    AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuildArgs: []),
    AppBuildRecipe(
      name: "kit", workspace: "PersonaKit.xcworkspace", scheme: "PersonaKitApp", xcodebuildArgs: []
    ),
  ]
  let config = BuildCompareConfig(schemaVersion: 1, appRecipes: recipes)

  let kitRecipes = config.appRecipes(forWorkspace: "PersonaKit.xcworkspace")
  #expect(kitRecipes.count == 2)

  let otherRecipes = config.appRecipes(forWorkspace: "Other.xcworkspace")
  #expect(otherRecipes.count == 1)
  #expect(otherRecipes[0].name == "default")
}
