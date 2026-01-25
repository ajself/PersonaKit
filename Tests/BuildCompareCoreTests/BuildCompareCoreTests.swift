import BuildCompareCore
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
func markdownReportIncludesKeySectionsAndDeltas() {
  let baseBuild = BuildStepMetrics(
    duration_seconds: 10,
    warnings_count: 1,
    timing_summary: nil,
    log_path: "/tmp/base.log",
    output_path: nil
  )
  let headBuild = BuildStepMetrics(
    duration_seconds: 12,
    warnings_count: 3,
    timing_summary: nil,
    log_path: "/tmp/head.log",
    output_path: nil
  )

  let base = RevisionMetrics(
    sha: "base",
    app: AppMetrics(build_recipe: "default", clean_build: baseBuild, incremental_build: nil, binary: nil),
    cli: CliMetrics(clean_build: baseBuild, incremental_build: nil, binaries: []),
    tests: TestMetrics(duration_seconds: 5, warnings_count: 0, success: true, log_path: "/tmp/tests.log")
  )

  let head = RevisionMetrics(
    sha: "head",
    app: AppMetrics(build_recipe: "legacy", clean_build: headBuild, incremental_build: nil, binary: nil),
    cli: CliMetrics(clean_build: headBuild, incremental_build: nil, binaries: []),
    tests: TestMetrics(duration_seconds: 6, warnings_count: 1, success: true, log_path: "/tmp/tests.log")
  )

  let metadata = RunMetadata(
    timestamp_utc: "2026-01-25T00:00:00Z",
    repo_root: "/repo",
    base_sha: "base",
    head_sha: "head",
    worktree_root: "/tmp/worktrees",
    output_root: "/tmp/output",
    scheme: "PersonaKitApp",
    configuration: "Release",
    swift_version: "Swift 6.2",
    xcode_version: "Xcode 16"
  )

  let report = markdownReport(base: base, head: head, metadata: metadata)
  #expect(report.contains("# Build Compare Report"))
  #expect(report.contains("Base: base"))
  #expect(report.contains("Head: head"))
  #expect(report.contains("App build recipes: base=default, head=legacy"))
  #expect(report.contains("| App clean build | 10.00 | 12.00 | +2.00s |"))
  #expect(report.contains("| Tests | 5.00 | 6.00 | +1.00s |"))
  #expect(report.contains("| Success | true | true |"))
  #expect(report.contains("## Warnings"))
  #expect(report.contains("| App clean build | 1 | 3 | 2 |"))
}

@Test
func configFiltersRecipesByWorkspace() throws {
  let recipes = [
    AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuild_args: []),
    AppBuildRecipe(name: "pad", workspace: "PersonaPad.xcworkspace", scheme: "PersonaPadApp", xcodebuild_args: [])
  ]
  let config = BuildCompareConfig(schema_version: 1, app_recipes: recipes)

  let padRecipes = config.appRecipes(forWorkspace: "PersonaPad.xcworkspace")
  #expect(padRecipes.count == 2)

  let kitRecipes = config.appRecipes(forWorkspace: "PersonaKit.xcworkspace")
  #expect(kitRecipes.count == 1)
  #expect(kitRecipes[0].name == "default")
}
