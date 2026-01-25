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
func buildRunSectionIncludesKeySections() {
  let build = BuildStepMetrics(
    durationSeconds: 10,
    warningsCount: 1,
    timingSummary: nil,
    logPath: "/tmp/base.log",
    outputPath: nil
  )

  let metrics = BuildRunMetrics(
    sha: "abc123",
    app: AppMetrics(
      buildRecipe: "default", cleanBuild: build, incrementalBuild: nil, binary: nil
    ),
    cli: CliMetrics(cleanBuild: build, incrementalBuild: nil, binaries: []),
    tests: TestMetrics(
      durationSeconds: 5, warningsCount: 0, success: true, logPath: "/tmp/tests.log"
    )
  )

  let metadata = BuildRunMetadata(
    timestampUTC: "2026-01-25T00:00:00Z",
    repoRoot: "/repo",
    revisionSha: "abc123",
    worktreePath: nil,
    outputRoot: "/tmp/output",
    scheme: "PersonaKitApp",
    configuration: "Release",
    swiftVersion: "Swift 6.2",
    xcodeVersion: "Xcode 16"
  )

  let report = BuildRunReport(schemaVersion: 1, run: metadata, metrics: metrics)
  var lines: [String] = []
  BuildRunReportFormatter.appendSection(to: &lines, report: report)
  let markdown = lines.joined(separator: "\n")

  #expect(markdown.contains("## Build Run"))
  #expect(markdown.contains("Revision: abc123"))
  #expect(markdown.contains("Worktree: current working tree"))
  #expect(markdown.contains("App build recipe: default"))
  #expect(markdown.contains("| App clean build | 10.00 |"))
  #expect(markdown.contains("| Tests | 5.00 |"))
  #expect(markdown.contains("| Success | true |"))
  #expect(markdown.contains("### Warnings"))
  #expect(markdown.contains("| App clean build | 1 |"))
}

@Test
func configFiltersRecipesByWorkspace() throws {
  let recipes = [
    AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuildArgs: []),
    AppBuildRecipe(
      name: "kit", workspace: "PersonaKit.xcworkspace", scheme: "PersonaKitApp", xcodebuildArgs: []
    ),
  ]
  let config = BuildRunConfig(schemaVersion: 1, appRecipes: recipes)

  let kitRecipes = config.appRecipes(forWorkspace: "PersonaKit.xcworkspace")
  #expect(kitRecipes.count == 2)

  let otherRecipes = config.appRecipes(forWorkspace: "Other.xcworkspace")
  #expect(otherRecipes.count == 1)
  #expect(otherRecipes[0].name == "default")
}
