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
  func exportOmitsEmbeddedTopLevelEssentialHeadings() throws {
    let root = fixtureKitRootURL()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    #expect(output.contains("## environment\n\n- Platform: macOS"))
    #expect(!output.contains("## environment\n# Environment"))
    #expect(!output.contains("## persona-activation-contract\n# Persona Activation Contract"))
  }

  @Test
  func exportFailsWhenValidationErrorsExist() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let missingURL = root.appendingPathComponent("Packs/essentials/tools-and-constraints.md")
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
  func exportExpandsMatchedReferencesWhenTriggerInputsProvided() throws {
    let root = fixtureKitRootURL()

    let output = try SessionExporter.export(
      root: root,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      targetPaths: ["Sources/FooView.swift"],
      referenceTags: ["swiftui"]
    )

    #expect(output.contains("# Available References"))
    #expect(output.contains("# Expanded References"))
    #expect(output.contains("## swift-style-guide-reference"))
    #expect(output.contains("rule[0]: paths=**/*.swift => Sources/FooView.swift"))
    #expect(output.contains("## swiftui-style-guide-reference"))
    #expect(output.contains("rule[0]: referenceTags=swiftui"))
    #expect(output.contains("Extended SwiftUI ownership and composition guidance"))
  }

  @Test
  func exportFailsClosedWhenMatchedReferenceBodyIsMissing() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let missingURL = root.appendingPathComponent("Packs/references/swiftui-style-guide-reference.md")
    try FileManager.default.removeItem(at: missingURL)

    do {
      _ = try SessionExporter.export(
        root: root,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: [],
        targetPaths: ["Sources/FooView.swift"],
        referenceTags: ["swiftui"]
      )
      #expect(Bool(false))
    } catch let error as ExportError {
      switch error {
      case .validationFailed(let result):
        #expect(
          result.errors.contains { validationError in
            validationError.entityType == ValidationEntityType.reference
              && validationError.field == "body"
              && validationError.expectedPath == "Packs/references/swiftui-style-guide-reference.md"
          }
        )
      case .readFailed(let message):
        #expect(message.contains("Packs/references/swiftui-style-guide-reference.md"))
      default:
        #expect(Bool(false))
      }
    }
  }

  @Test
  func referenceExpansionRejectsEscapingReferenceIDWithoutReadingEscapedFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    let leakedURL = root.appendingPathComponent("Packs/leaked-reference.md")
    let referencesURL = root.appendingPathComponent("Packs/references")

    try FileManager.default.createDirectory(
      at: referencesURL,
      withIntermediateDirectories: true
    )
    try "# Leaked\n\nDo not read.\n".write(
      to: leakedURL,
      atomically: true,
      encoding: .utf8
    )

    let match = ResolvedReferenceMatch(
      id: "../leaked-reference",
      name: "Leaked",
      summary: "Escaping reference body",
      sources: [],
      matchedRules: []
    )

    do {
      _ = try ReferenceSupport.loadExpandedDocuments(
        matches: [match],
        scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil)
      )
      #expect(Bool(false))
    } catch let error as ReferenceResolutionError {
      if case .missingBody(let id, let expectedPath) = error {
        #expect(id == "../leaked-reference")
        #expect(expectedPath == "Packs/references/<invalid>.md")
        return
      }

      #expect(Bool(false))
    }
  }
}
