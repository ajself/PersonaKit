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
          kits: 3,
          directives: 1,
          intents: 1,
          skills: 2,
          essentials: 5
        )
    )
  }

  @Test
  func validateMissingEssentialFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let missingURL = root.appendingPathComponent("Packs/essentials/swiftui-style-guide.md")
    try FileManager.default.removeItem(at: missingURL)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors == [
        ValidationError(
          entityType: .kit,
          entityId: "swiftui-style",
          field: "essentialIds",
          missingId: "swiftui-style-guide",
          expectedPath: "Packs/essentials/swiftui-style-guide.md",
          message: "Missing essential file at Packs/essentials/swiftui-style-guide.md."
        )
      ]
    )
  }

  @Test
  func validateUnknownKitId() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let personaURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
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

    let result = try Validator.validate(root: root)

    #expect(
      result.errors == [
        ValidationError(
          entityType: .persona,
          entityId: "senior-swiftui-engineer",
          field: "defaultKitIds",
          missingId: "unknown-kit",
          expectedPath: nil,
          message: "Missing kit id \"unknown-kit\"."
        )
      ]
    )
  }

  @Test
  func validateSchemaViolation() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let personaURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    let data = try Data(contentsOf: personaURL)
    var object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    object?["id"] = nil

    let updatedData = try JSONSerialization.data(withJSONObject: object ?? [:], options: [.prettyPrinted, .sortedKeys])
    try updatedData.write(to: personaURL)

    let result = try Validator.validate(root: root)

    #expect(result.errors.count >= 1)
    #expect(result.errors.contains { $0.expectedPath == "Packs/personas/senior-swiftui-engineer.persona.json" })
    #expect(result.errors.contains { $0.field == "schema" && $0.message.contains("Missing required property \"id\"") })
  }

  @Test
  func validateSchemaErrorsSuppressReferenceCascadeNoise() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let intentURL = root.appendingPathComponent("Packs/intents/swift-refactor-safe.intent.json")
    let data = try Data(contentsOf: intentURL)
    var object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    object?["parameterConstraints"] = NSNull()
    object?["requiresSkillIds"] = ["missing-skill"]

    let updatedData = try JSONSerialization.data(
      withJSONObject: object ?? [:],
      options: [.prettyPrinted, .sortedKeys]
    )
    try updatedData.write(to: intentURL)

    let result = try Validator.validate(root: root)

    #expect(result.errors.count == 1)
    #expect(result.errors.first?.entityType == .intent)
    #expect(result.errors.first?.field == "schema")
    #expect(result.errors.first?.expectedPath == "Packs/intents/swift-refactor-safe.intent.json")
    #expect(result.errors.first?.message.contains("Schema intentTemplate.schema.json") == true)
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
          entityType: .essentials,
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
  func validateIntentParameterConstraintRequiresMultipleParameters() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let intentURL = root.appendingPathComponent("Packs/intents/swift-refactor-safe.intent.json")
    let data = try Data(contentsOf: intentURL)
    let intent = try JSONDecoder().decode(IntentTemplate.self, from: data)
    let updatedIntent = IntentTemplate(
      id: intent.id,
      version: intent.version,
      name: intent.name,
      description: intent.description,
      parameters: intent.parameters,
      parameterConstraints: [
        IntentTemplate.ParameterConstraint(
          kind: "allDistinct",
          parameterNames: ["targetFiles"]
        )
      ],
      includesEssentialIds: intent.includesEssentialIds,
      requiresSkillIds: intent.requiresSkillIds,
      risk: intent.risk
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(updatedIntent).write(to: intentURL)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors == [
        ValidationError(
          entityType: .intent,
          entityId: "swift-refactor-safe",
          field: "parameterConstraints",
          missingId: nil,
          expectedPath: nil,
          message: "Constraint kind \"allDistinct\" must reference at least two parameter names."
        )
      ]
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
