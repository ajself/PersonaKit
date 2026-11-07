import Foundation
import Testing

@testable import ContextCore

/// A handoff validates only what its session reaches; errors elsewhere are warnings.
struct ScopedValidationTests {
  private static let sessionScope = ValidationSessionScope(
    sessionId: "senior-swiftui-engineer_apply-style",
    personaId: "senior-swiftui-engineer",
    directiveId: "apply-style",
    kitOverrides: []
  )

  @Test
  func schemaErrorsNameTheEntityTheyBelongTo() throws {
    let root = try makeFixtureCopy()
    try writePersonaWithUnknownCapability(id: "other-persona", root: root)

    let result = try Validator.validate(root: root)
    let schemaError = try #require(result.errors.first { $0.field == "schema" })

    #expect(schemaError.entityType == .persona)
    #expect(schemaError.entityId == "other-persona")
    #expect(schemaError.lineDescription().hasPrefix("persona other-persona schema: "))
  }

  @Test
  func errorsOutsideTheSessionAreWarnings() throws {
    let root = try makeFixtureCopy()
    try writeBrokenExtraSession(root: root)
    try writePersonaWithUnknownCapability(id: "other-persona", root: root)

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(scoped.errors.isEmpty)
    #expect(scoped.outOfScopeErrors.map(\.entityId) == ["broken-extra", "other-persona"])
    #expect(scoped.summary.hasSuffix("warnings=2 errors=0"))
    #expect(
      scoped.warningLines == scoped.outOfScopeErrors.map { $0.lineDescription() }
    )

    // The library-wide check stays strict.
    let strict = try Validator.validate(root: root)
    #expect(!strict.errors.isEmpty)
    #expect(strict.outOfScopeErrors.isEmpty)
  }

  @Test
  func anUnrelatedSchemaErrorDoesNotHideTheSessionsOwnReferenceErrors() throws {
    let root = try makeFixtureCopy()
    try writePersonaWithUnknownCapability(id: "other-persona", root: root)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Packs/skills/tools-and-constraints.md"))

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(scoped.errors.map(\.entityId) == ["tools-and-constraints"])
    #expect(scoped.outOfScopeErrors.map(\.entityId) == ["other-persona"])
  }

  @Test
  func aSchemaErrorInTheSessionsPersonaBlocks() throws {
    let root = try makeFixtureCopy()
    try writePersonaWithUnknownCapability(id: "senior-swiftui-engineer", root: root)

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(scoped.errors.map(\.entityId) == ["senior-swiftui-engineer"])
    #expect(scoped.errors.first?.field == "schema")
  }

  @Test
  func anErrorTiedToNoEntityBlocks() throws {
    let root = try makeFixtureCopy()
    // A pack file with no id cannot load, so the library cannot be trusted for any handoff.
    try Data(#"{"version": "1.0"}"#.utf8)
      .write(to: root.appendingPathComponent("Packs/kits/nameless.kit.json"))

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(!scoped.errors.isEmpty)
    #expect(scoped.errors.allSatisfy { $0.entityId == nil })
    #expect(scoped.outOfScopeErrors.isEmpty)
  }

  @Test
  func aWorkstreamConflictReportedOnAnotherDirectiveStillBlocks() throws {
    let root = try makeWorkstreamFixtureRoot()
    let valid = makeValidFixtureWorkstream()
    // Sorts before `apply-style`, so the conflict is reported on this directive.
    try writeDirective(
      id: "aa-conflicting",
      root: root,
      workstream: Directive.Workstream(
        id: valid.id,
        phase: valid.phase,
        entrySessionId: valid.entrySessionId,
        requiredCloseoutSessionId: "style-followup",
        nodes: valid.nodes,
        edges: valid.edges
      )
    )

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(
      scoped.errors.contains {
        $0.entityId == "aa-conflicting" && $0.field == "workstream.requiredCloseoutSessionId"
      }
    )
  }

  @Test
  func aWorkstreamErrorOnAnUnrelatedDirectiveIsAWarningEvenWhenItsIdCollides() throws {
    let root = try makeWorkstreamFixtureRoot()
    // An unrelated workstream whose node names a missing session spelled like this session's workstream id.
    try writeDirective(
      id: "zz-other",
      root: root,
      workstream: Directive.Workstream(
        id: "other-workstream",
        phase: "planning",
        entrySessionId: "style-workstream",
        requiredCloseoutSessionId: "style-workstream",
        nodes: [.init(sessionId: "style-workstream", phase: "planning")],
        edges: []
      )
    )

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: Self.sessionScope
    )

    #expect(scoped.errors.isEmpty)
    #expect(scoped.outOfScopeErrors.contains { $0.entityId == "zz-other" && $0.missingId == "style-workstream" })
  }

  @Test
  func aKitBlocksOnlyWhenTheSessionUsesIt() throws {
    let root = try makeFixtureCopy()
    let kit: [String: Any] = [
      "id": "extra-kit",
      "version": "1.0",
      "name": "Extra Kit",
      "summary": "Names a skill that does not exist.",
      "skillIds": ["missing-skill"],
    ]
    try JSONSerialization.data(withJSONObject: kit, options: [.sortedKeys])
      .write(to: root.appendingPathComponent("Packs/kits/extra-kit.kit.json"))
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)

    let unused = try Validator.validate(scopes: scopes, session: Self.sessionScope)
    let overridden = try Validator.validate(
      scopes: scopes,
      session: ValidationSessionScope(
        sessionId: nil,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: ["extra-kit"]
      )
    )

    #expect(unused.errors.isEmpty)
    #expect(unused.outOfScopeErrors.map(\.entityId) == ["extra-kit"])
    #expect(overridden.errors.map(\.entityId) == ["extra-kit"])
    #expect(overridden.outOfScopeErrors.isEmpty)
  }

  @Test
  func aHandoffWithNoSessionFileTreatsEverySessionFileAsElsewhere() throws {
    let root = try makeFixtureCopy()
    try writeBrokenExtraSession(root: root)

    let scoped = try Validator.validate(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      session: ValidationSessionScope(
        sessionId: nil,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: []
      )
    )

    #expect(scoped.errors.isEmpty)
    #expect(scoped.outOfScopeErrors.map(\.entityId) == ["broken-extra"])
  }

  @Test
  func exportSucceedsWithWarningsAndKeepsThemOutOfTheMarkdown() throws {
    let root = try makeFixtureCopy()
    try writeBrokenExtraSession(root: root)

    let export = try SessionExporter.exportWithValidation(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )
    let clean = try SessionExporter.export(
      root: fixtureKitRootURL(),
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      sessionId: "senior-swiftui-engineer_apply-style"
    )

    #expect(export.markdown == clean)
    #expect(export.validation.outOfScopeErrors.map(\.entityId) == ["broken-extra"])
  }

  @Test
  func groundingLookupSucceedsWithWarnings() throws {
    let root = try makeFixtureCopy()
    try writeBrokenExtraSession(root: root)

    let lookup = try WorkflowGroundingSkillResolver.resolveWithValidation(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      input: SkillTriggerSelectionInput(targetPaths: [], skillTags: [])
    )

    #expect(lookup.validation.errors.isEmpty)
    #expect(lookup.validation.outOfScopeErrors.map(\.entityId) == ["broken-extra"])
  }

  private func makeFixtureCopy() throws -> URL {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    return root
  }

  private func writeBrokenExtraSession(root: URL) throws {
    try writeSessionFile(
      SessionFile(
        id: "broken-extra",
        personaId: "missing-persona",
        directiveId: "apply-style",
        kitOverrides: []
      ),
      root: root
    )
  }

  /// A persona that decodes but breaks the schema: capabilities are an enum the decoder doesn't check.
  private func writePersonaWithUnknownCapability(id: String, root: URL) throws {
    let sourceURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: sourceURL)) as? [String: Any]
    )
    json["id"] = id
    json["forbiddenCapabilities"] = ["not-a-capability"]

    let destinationURL = root.appendingPathComponent("Packs/personas/\(id).persona.json")
    try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
      .write(to: destinationURL)
  }
}
