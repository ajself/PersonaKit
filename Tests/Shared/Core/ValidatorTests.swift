import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct ValidatorTests {
  @Test
  func validateStarterKitClean() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let result = try Validator.validate(root: root)

    #expect(result.errors.isEmpty)
    #expect(
      result.counts
        == ValidationCounts(
          personas: 1,
          kits: 1,
          directives: 1,
          skills: 2
        )
    )
  }

  @Test
  func validateRejectsEscapingReferenceBodyIDWithoutAcceptingEscapedFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try "# Escaped reference\n".write(
      to: root.appendingPathComponent("Packs/escaped-reference.md"),
      atomically: true,
      encoding: .utf8
    )

    let skillURL = root.appendingPathComponent("Packs/skills/escaped-reference.skill.json")
    let skill = Skill(
      id: "../escaped-reference",
      version: "1.0",
      name: "Escaped Reference",
      description: "Grounding skill with escaping body id.",
      triggerRules: [
        SkillTriggerRule(skillTags: ["escaped"])
      ]
    )
    try encodeSortedJSON(skill).write(to: skillURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .skill,
          entityId: "../escaped-reference",
          field: "body",
          missingId: "../escaped-reference",
          expectedPath: "Packs/skills/<invalid>.md",
          message: "Unsafe skill id path segment \"../escaped-reference\"."
        )
      )
    )
  }

  @Test
  func validateRejectsEscapingReferenceBodySymlink() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let outsideURL = try makeTempDirectory().appendingPathComponent("linked-reference.md")
    try "# Outside reference\n".write(
      to: outsideURL,
      atomically: true,
      encoding: .utf8
    )

    let symlinkURL = root.appendingPathComponent("Packs/skills/linked-reference.md")
    try FileManager.default.createSymbolicLink(
      at: symlinkURL,
      withDestinationURL: outsideURL
    )

    let skillURL = root.appendingPathComponent("Packs/skills/linked-reference.skill.json")
    let skill = Skill(
      id: "linked-reference",
      version: "1.0",
      name: "Linked Reference",
      description: "Grounding skill body escapes through a symlink.",
      triggerRules: [
        SkillTriggerRule(skillTags: ["linked"])
      ]
    )
    try encodeSortedJSON(skill).write(to: skillURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .skill,
          entityId: "linked-reference",
          field: "body",
          missingId: "linked-reference",
          expectedPath: "Packs/skills/linked-reference.md",
          message: "Unsafe grounding-skill body path for id \"linked-reference\"."
        )
      )
    )
  }

  @Test
  func validateRejectsBackslashReferenceBodyID() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let skillURL = root.appendingPathComponent("Packs/skills/backslash-reference.skill.json")
    let skill = Skill(
      id: "nested\\reference",
      version: "1.0",
      name: "Backslash Reference",
      description: "Grounding skill body id contains a path separator.",
      triggerRules: [
        SkillTriggerRule(skillTags: ["backslash"])
      ]
    )
    try encodeSortedJSON(skill).write(to: skillURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .skill,
          entityId: "nested\\reference",
          field: "body",
          missingId: "nested\\reference",
          expectedPath: "Packs/skills/<invalid>.md",
          message: "Unsafe skill id path segment \"nested\\reference\"."
        )
      )
    )
  }

  @Test
  func validateUnknownKitId() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let personaURL = root.appendingPathComponent("Packs/personas/solo-developer.persona.json")
    let data = try Data(contentsOf: personaURL)
    let persona = try JSONDecoder().decode(Persona.self, from: data)
    let updatedPersona = Persona(
      id: persona.id,
      version: persona.version,
      name: persona.name,
      summary: persona.summary,
      responsibilities: persona.responsibilities,
      values: persona.values,
      nonGoals: persona.nonGoals,
      defaultKitIds: ["unknown-kit"],
      allowedSkillIds: persona.allowedSkillIds,
      forbiddenSkillIds: persona.forbiddenSkillIds
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(updatedPersona).write(to: personaURL)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Sessions/solo-dev.session.json"))

    let result = try Validator.validate(root: root)

    #expect(
      result.errors == [
        ValidationError(
          entityType: .persona,
          entityId: "solo-developer",
          field: "defaultKitIds",
          missingId: "unknown-kit",
          expectedPath: nil,
          message: "Missing kit id \"unknown-kit\".",
          referencesUnresolvedID: true
        )
      ]
    )
  }

  @Test
  func validateSchemaViolation() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let personaURL = root.appendingPathComponent("Packs/personas/solo-developer.persona.json")
    let data = try Data(contentsOf: personaURL)
    var object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    object?["id"] = nil

    let updatedData = try JSONSerialization.data(withJSONObject: object ?? [:], options: [.prettyPrinted, .sortedKeys])
    try updatedData.write(to: personaURL)

    let result = try Validator.validate(root: root)

    #expect(result.errors.count >= 1)
    #expect(result.errors.contains { $0.expectedPath == "Packs/personas/solo-developer.persona.json" })
    #expect(result.errors.contains { $0.field == "schema" && $0.message.contains("Missing required property \"id\"") })
  }

  @Test
  func validateSchemaErrorsSuppressReferenceCascadeNoise() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    // A schema-invalid entity must yield exactly its schema error: when any schema
    // error exists, all reference/skill checks are suppressed so a dangling id does
    // not add cascade noise. `parameters: null` is schema-invalid (array expected)
    // yet still decodes, and `requiresSkillIds` points at a missing skill that would
    // otherwise raise its own error.
    let directiveURL = root.appendingPathComponent("Packs/directives/apply-style.directive.json")
    let data = try Data(contentsOf: directiveURL)
    var object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    object?["parameters"] = NSNull()
    object?["requiresSkillIds"] = ["missing-skill"]

    let updatedData = try JSONSerialization.data(
      withJSONObject: object ?? [:],
      options: [.prettyPrinted, .sortedKeys]
    )
    try updatedData.write(to: directiveURL)

    let result = try Validator.validate(root: root)

    #expect(result.errors.count == 1)
    #expect(result.errors.first?.entityType == .directive)
    #expect(result.errors.first?.field == "schema")
    #expect(result.errors.first?.expectedPath == "Packs/directives/apply-style.directive.json")
    #expect(result.errors.contains { $0.field == "requiresSkillIds" } == false)
  }

  @Test
  func validateMissingPacksDirectoryProducesDeterministicRegistryLoadError() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )

    let result = try Validator.validate(root: root)

    #expect(result.counts == .zero)
    #expect(
      result.errors == [
        ValidationError(
          entityType: .kit,
          entityId: nil,
          field: "file",
          missingId: nil,
          expectedPath: "Packs",
          message: "Missing Packs directory."
        )
      ]
    )
  }

  @Test
  func validateRejectsPackEntityPathWhenItIsAFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    let packsURL = root.appendingPathComponent("Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )
    try Data("not a directory".utf8).write(to: packsURL.appendingPathComponent("personas"))

    let result = try Validator.validate(root: root)

    #expect(result.counts == .zero)
    #expect(
      result.errors == [
        ValidationError(
          entityType: .persona,
          entityId: nil,
          field: "file",
          missingId: nil,
          expectedPath: "Packs/personas",
          message: "Expected directory."
        )
      ]
    )
  }

  @Test
  func validateRejectsSessionsPathWhenItIsAFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    let sessionsURL = root.appendingPathComponent("Sessions")
    try FileManager.default.removeItem(at: sessionsURL)
    try Data("not a directory".utf8).write(to: sessionsURL)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .session,
          entityId: nil,
          field: "sessionFile",
          missingId: nil,
          expectedPath: "Sessions",
          message: "Session discovery path is not a directory: Sessions."
        )
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamPassesWhenSessionsAndRoutingAreValid() throws {
    let root = try makeWorkstreamFixtureRoot()

    let result = try Validator.validate(root: root)

    #expect(result.errors.isEmpty)
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenPhaseDoesNotMatchNode() throws {
    let root = try makeWorkstreamFixtureRoot()
    var workstream = makeValidFixtureWorkstream()
    workstream = Directive.Workstream(
      id: workstream.id,
      phase: "missing-phase",
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: workstream.edges
    )
    try writeApplyStyleDirective(root: root, workstream: workstream)

    let result = try Validator.validate(root: root)

    #expect(hasDirectiveWorkstreamError(result, field: "workstream.phase", text: "must match exactly one node phase"))
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenEntrySessionIsMissingFromNodes() throws {
    let root = try makeWorkstreamFixtureRoot()
    var workstream = makeValidFixtureWorkstream()
    workstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: "missing-entry",
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: workstream.edges
    )
    try writeApplyStyleDirective(root: root, workstream: workstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.entrySessionId",
        text: "must be declared in workstream nodes"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenRequiredCloseoutSessionIsMissingFromNodes() throws {
    let root = try makeWorkstreamFixtureRoot()
    var workstream = makeValidFixtureWorkstream()
    workstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: "missing-closeout",
      nodes: workstream.nodes,
      edges: workstream.edges
    )
    try writeApplyStyleDirective(root: root, workstream: workstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.requiredCloseoutSessionId",
        text: "must be declared in workstream nodes"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenNodeSessionFileIsMissing() throws {
    let root = try makeWorkstreamFixtureRoot()
    try removeSessionFile(id: "style-followup", root: root)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.nodes.sessionId",
        text: "Missing session file for workstream node id \"style-followup\"."
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenEdgeTargetsUndeclaredNode() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: workstream.edges + [
        .init(
          fromSessionId: "style-followup",
          toSessionId: "missing-node",
          kind: "optional-follow-up"
        )
      ]
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.edges.toSessionId",
        text: "must be declared in workstream nodes"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenNodePhaseIsDuplicated() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes + [
        .init(
          sessionId: "style-extra",
          phase: "followup"
        )
      ],
      edges: workstream.edges
    )
    try writeSessionFile(
      SessionFile(
        id: "style-extra",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: []
      ),
      root: root
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.nodes.phase",
        text: "Duplicate workstream node phase"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenNodeSessionIDIsDuplicated() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes + [
        .init(
          sessionId: "style-followup",
          phase: "review"
        )
      ],
      edges: workstream.edges
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.nodes.sessionId",
        text: "Duplicate workstream node session id"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenEdgeIsDuplicated() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: workstream.edges + [workstream.edges[0]]
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(hasDirectiveWorkstreamError(result, field: "workstream.edges", text: "Duplicate workstream edge"))
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenEdgeKindIsUnsupported() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: [
        .init(
          fromSessionId: "senior-swiftui-engineer_apply-style",
          toSessionId: "style-followup",
          kind: "side-quest"
        )
      ]
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains { error in
        error.entityType == .directive
          && error.field == "schema"
          && error.expectedPath == "Packs/directives/apply-style.directive.json"
          && error.message.contains("Value \"side-quest\" must be one of")
          && error.message.contains("location=/workstream/edges/0/kind")
      }
    )
  }

  @Test
  func schemaValidatorReportsWorkstreamEdgeKindEnumPath() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: [
        .init(
          fromSessionId: "senior-swiftui-engineer_apply-style",
          toSessionId: "style-followup",
          kind: "side-quest"
        )
      ]
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let directiveURL = root.appendingPathComponent("Packs/directives/apply-style.directive.json")
    let errors = SchemaValidator.validate(
      jsonData: try Data(contentsOf: directiveURL),
      schemaName: "directive.schema.json",
      relativePath: "Packs/directives/apply-style.directive.json"
    )

    #expect(errors.count == 1)
    #expect(errors.first?.instanceLocation == "/workstream/edges/0/kind")
    #expect(errors.first?.message.contains("Value \"side-quest\" must be one of") == true)
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenRequiredCloseoutIsUnreachable() throws {
    let root = try makeWorkstreamFixtureRoot()
    let workstream = makeValidFixtureWorkstream()
    let updatedWorkstream = Directive.Workstream(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodes: workstream.nodes,
      edges: [
        .init(
          fromSessionId: "senior-swiftui-engineer_apply-style",
          toSessionId: "style-followup",
          kind: "required-next"
        )
      ]
    )
    try writeApplyStyleDirective(root: root, workstream: updatedWorkstream)

    let result = try Validator.validate(root: root)

    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.requiredCloseoutSessionId",
        text: "is not reachable from entry session id"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamIgnoresMalformedUnrelatedSessionFiles() throws {
    let root = try makeWorkstreamFixtureRoot()
    let malformedSessionURL = root.appendingPathComponent("Sessions/broken.session.json")
    try """
    {
      "id": "broken",
      "personaId": 42
    }
    """.write(
      to: malformedSessionURL,
      atomically: true,
      encoding: .utf8
    )

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .session,
          entityId: "broken",
          field: "sessionFile",
          missingId: "broken",
          expectedPath: "Sessions/broken.session.json",
          message:
            "Failed to decode session file for broken: The data couldn’t be read because it isn’t in the correct format."
        )
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenNodeSessionFileIdDoesNotMatchFilename() throws {
    let root = try makeWorkstreamFixtureRoot()
    let mismatchedSessionURL = root.appendingPathComponent("Sessions/style-followup.session.json")
    try """
    {
      "directiveId": "apply-style",
      "id": "style-closeout",
      "kitOverrides": [],
      "personaId": "senior-swiftui-engineer"
    }
    """.write(
      to: mismatchedSessionURL,
      atomically: true,
      encoding: .utf8
    )

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .session,
          entityId: "style-followup",
          field: "id",
          missingId: "style-followup",
          expectedPath: "Sessions/style-followup.session.json",
          message:
            "Session id mismatch in Sessions/style-followup.session.json. Expected style-followup, got style-closeout."
        )
      )
    )
    #expect(
      hasDirectiveWorkstreamError(
        result,
        field: "workstream.nodes.sessionId",
        text: "failed to resolve"
      )
    )
  }

  @Test
  func validateDirectiveWorkstreamFailsWhenSharedWorkstreamEntrySessionDiffers() throws {
    let root = try makeWorkstreamFixtureRoot()
    let conflictingWorkstream = Directive.Workstream(
      id: "style-workstream",
      phase: "followup",
      entrySessionId: "style-followup",
      requiredCloseoutSessionId: "style-closeout",
      nodes: makeValidFixtureWorkstream().nodes,
      edges: makeValidFixtureWorkstream().edges
    )
    try writeDirective(
      id: "style-followup",
      title: "Style followup",
      root: root,
      workstream: conflictingWorkstream
    )

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains { error in
        error.entityType == .directive
          && error.field == "workstream.entrySessionId"
          && error.message.contains("style-workstream")
          && error.message.contains("apply-style")
          && error.message.contains("style-followup")
      }
    )
  }
}

private func hasDirectiveWorkstreamError(
  _ result: ValidationResult,
  field: String,
  text: String
) -> Bool {
  result.errors.contains { error in
    error.entityType == .directive
      && error.entityId == "apply-style"
      && error.field == field
      && error.message.contains(text)
  }
}
