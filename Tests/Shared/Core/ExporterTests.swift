import Foundation
import Testing

@testable import ContextCore

struct ExporterTests {
  @Test
  func exportMatchesGoldenFile() throws {
    let root = fixtureKitRootURL()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func exportMatchesGoldenFileUsingSession() throws {
    let root = fixtureKitRootURL()
    let session = try SessionFileLoader.load(
      root: root,
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    let output = try SessionExporter.export(
      root: root,
      personaId: session.personaId,
      directiveId: session.directiveId,
      kitOverrides: session.kitOverrides ?? []
    )

    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func exportOmitsEmbeddedTopLevelHeadingsInExpandedBodies() throws {
    let root = fixtureKitRootURL()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    // The always-on `tools-and-constraints` grounding skill inlines its body in
    // `# Expanded Skills`; its embedded top-level heading is dropped since the
    // `## <id>` header already labels the block.
    #expect(output.contains("- rule[0]: always-on\n\n- No large refactors"))
    #expect(!output.contains("always-on\n\n# Tools & Constraints"))
    #expect(!output.contains("## persona-activation-contract\n# Persona Activation Contract"))
  }

  @Test
  func exportPromotesChecksManifestAsBoundariesAndDropsStopPoints() throws {
    let output = try SessionExporter.export(
      root: fixtureKitRootURL(),
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    #expect(output.contains("# Boundaries"))
    #expect(
      output.contains("- command.swift-test — `swift test` — directive:apply-style [verification]")
    )
    // Class-3 review gates own the requires-review steps; the redundant `Stop Points`
    // block that only re-listed them is gone.
    #expect(
      output.contains("- review.avoid-unrelated-refactors — Avoid unrelated refactors. — directive:apply-style [steps]")
    )
    #expect(!output.contains("Stop Points:"))
  }

  @Test
  func exportFailsWhenValidationErrorsExist() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let missingURL = root.appendingPathComponent("Packs/skills/tools-and-constraints.md")
    try FileManager.default.removeItem(at: missingURL)

    do {
      _ = try SessionExporter.export(
        root: root,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: []
      )
      #expect(Bool(false))
    } catch let error as ExportError {
      if case .validationFailed = error {
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func exportIncludesWorkstreamSectionWhenDirectiveDeclaresRouting() throws {
    let root = try makeWorkstreamFixtureRoot()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style_workstream.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func exportExpandsMatchedGroundingSkillsWhenTriggerInputsProvided() throws {
    let root = fixtureKitRootURL()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      targetPaths: ["Sources/FooView.swift"],
      skillTags: ["swiftui"]
    )

    #expect(output.contains("# Available Skills"))
    #expect(output.contains("# Expanded Skills"))
    #expect(output.contains("## swift-style-guide-reference"))
    #expect(output.contains("rule[0]: paths=**/*.swift => Sources/FooView.swift"))
    #expect(output.contains("## swiftui-style-guide-reference"))
    #expect(output.contains("rule[0]: skillTags=swiftui"))
    #expect(output.contains("Extended SwiftUI ownership and composition guidance"))
  }

  @Test
  func exportFailsClosedWhenMatchedGroundingSkillBodyIsMissing() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let missingURL = root.appendingPathComponent("Packs/skills/swiftui-style-guide-reference.md")
    try FileManager.default.removeItem(at: missingURL)

    do {
      _ = try SessionExporter.export(
        root: root,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: [],
        targetPaths: ["Sources/FooView.swift"],
        skillTags: ["swiftui"]
      )
      #expect(Bool(false))
    } catch let error as ExportError {
      switch error {
      case .validationFailed(let result):
        #expect(
          result.errors.contains { validationError in
            validationError.entityType == ValidationEntityType.skill
              && validationError.field == "body"
              && validationError.expectedPath == "Packs/skills/swiftui-style-guide-reference.md"
          }
        )
      case .readFailed(let message):
        #expect(message.contains("Packs/skills/swiftui-style-guide-reference.md"))
      default:
        #expect(Bool(false))
      }
    }
  }

  @Test
  func groundingSkillExpansionRejectsEscapingIDWithoutReadingEscapedFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    let leakedURL = root.appendingPathComponent("Packs/leaked-reference.md")
    let skillsURL = root.appendingPathComponent("Packs/skills")

    try FileManager.default.createDirectory(
      at: skillsURL,
      withIntermediateDirectories: true
    )
    try "# Leaked\n\nDo not read.\n".write(
      to: leakedURL,
      atomically: true,
      encoding: .utf8
    )

    let match = ResolvedGroundingSkillMatch(
      id: "../leaked-reference",
      name: "Leaked",
      description: "Escaping grounding-skill body",
      sources: [],
      matchedRules: []
    )

    do {
      _ = try GroundingSkillSupport.loadExpandedDocuments(
        matches: [match],
        scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil)
      )
      #expect(Bool(false))
    } catch let error as GroundingSkillResolutionError {
      if case .missingBody(let id, let expectedPath) = error {
        #expect(id == "../leaked-reference")
        #expect(expectedPath == "Packs/skills/<invalid>.md")
        return
      }

      #expect(Bool(false))
    }
  }
}
