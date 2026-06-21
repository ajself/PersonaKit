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
          intents: 0,
          references: 1,
          skills: 0,
          essentials: 1
        )
    )
  }

  @Test
  func validateMissingEssentialFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let missingURL = root.appendingPathComponent("Packs/essentials/contract-boundaries.md")
    try FileManager.default.removeItem(at: missingURL)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Sessions/solo-dev.session.json"))

    let result = try Validator.validate(root: root)

    #expect(
      result.errors == [
        ValidationError(
          entityType: .kit,
          entityId: "cli-guardrails",
          field: "essentialIds",
          missingId: "contract-boundaries",
          expectedPath: "Packs/essentials/contract-boundaries.md",
          message: "Missing essential file at Packs/essentials/contract-boundaries.md.",
          referencesUnresolvedID: true
        )
      ]
    )
  }

  @Test
  func validateRejectsEscapingKitEssentialIDWithoutAcceptingEscapedFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(
      at: root.appendingPathComponent("Sessions/senior-swiftui-engineer_apply-style.session.json")
    )
    try "# Escaped\n".write(
      to: root.appendingPathComponent("Packs/escaped-essential.md"),
      atomically: true,
      encoding: .utf8
    )

    let kitURL = root.appendingPathComponent("Packs/kits/swiftui-style.kit.json")
    let kit = try JSONDecoder().decode(Kit.self, from: Data(contentsOf: kitURL))
    let updatedKit = Kit(
      id: kit.id,
      version: kit.version,
      name: kit.name,
      summary: kit.summary,
      essentialIds: ["../escaped-essential"],
      referenceIds: kit.referenceIds,
      intentTemplateIds: kit.intentTemplateIds,
      skillIds: kit.skillIds
    )

    try encodeSortedJSON(updatedKit).write(to: kitURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .kit,
          entityId: "swiftui-style",
          field: "essentialIds",
          missingId: "../escaped-essential",
          expectedPath: "Packs/essentials/<invalid>.md",
          message: "Unsafe essential id path segment \"../escaped-essential\"."
        )
      )
    )
  }

  @Test
  func validateRejectsEscapingIntentEssentialIDWithoutAcceptingEscapedFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(
      at: root.appendingPathComponent("Sessions/senior-swiftui-engineer_apply-style.session.json")
    )
    try "# Escaped\n".write(
      to: root.appendingPathComponent("Packs/escaped-intent-essential.md"),
      atomically: true,
      encoding: .utf8
    )

    let intentURL = root.appendingPathComponent("Packs/intents/swift-refactor-safe.intent.json")
    let intent = try JSONDecoder().decode(IntentTemplate.self, from: Data(contentsOf: intentURL))
    let updatedIntent = IntentTemplate(
      id: intent.id,
      version: intent.version,
      name: intent.name,
      description: intent.description,
      parameters: intent.parameters,
      parameterConstraints: intent.parameterConstraints,
      includesEssentialIds: ["../escaped-intent-essential"],
      requiresSkillIds: intent.requiresSkillIds,
      referenceIds: intent.referenceIds,
      risk: intent.risk
    )

    try encodeSortedJSON(updatedIntent).write(to: intentURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .intent,
          entityId: "swift-refactor-safe",
          field: "includesEssentialIds",
          missingId: "../escaped-intent-essential",
          expectedPath: "Packs/essentials/<invalid>.md",
          message: "Unsafe essential id path segment \"../escaped-intent-essential\"."
        )
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

    let referenceURL = root.appendingPathComponent("Packs/references/escaped-reference.reference.json")
    let reference = Reference(
      id: "../escaped-reference",
      version: "1.0",
      name: "Escaped Reference",
      summary: "Reference with escaping body id.",
      triggerRules: [
        ReferenceTriggerRule(referenceTags: ["escaped"])
      ]
    )
    try encodeSortedJSON(reference).write(to: referenceURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .reference,
          entityId: "../escaped-reference",
          field: "body",
          missingId: "../escaped-reference",
          expectedPath: "Packs/references/<invalid>.md",
          message: "Unsafe reference id path segment \"../escaped-reference\"."
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

    let symlinkURL = root.appendingPathComponent("Packs/references/linked-reference.md")
    try FileManager.default.createSymbolicLink(
      at: symlinkURL,
      withDestinationURL: outsideURL
    )

    let referenceURL = root.appendingPathComponent("Packs/references/linked-reference.reference.json")
    let reference = Reference(
      id: "linked-reference",
      version: "1.0",
      name: "Linked Reference",
      summary: "Reference body escapes through a symlink.",
      triggerRules: [
        ReferenceTriggerRule(referenceTags: ["linked"])
      ]
    )
    try encodeSortedJSON(reference).write(to: referenceURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .reference,
          entityId: "linked-reference",
          field: "body",
          missingId: "linked-reference",
          expectedPath: "Packs/references/linked-reference.md",
          message: "Unsafe reference body path for id \"linked-reference\"."
        )
      )
    )
  }

  @Test
  func validateRejectsBackslashReferenceBodyID() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

    let referenceURL = root.appendingPathComponent("Packs/references/backslash-reference.reference.json")
    let reference = Reference(
      id: "nested\\reference",
      version: "1.0",
      name: "Backslash Reference",
      summary: "Reference body id contains a path separator.",
      triggerRules: [
        ReferenceTriggerRule(referenceTags: ["backslash"])
      ]
    )
    try encodeSortedJSON(reference).write(to: referenceURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .reference,
          entityId: "nested\\reference",
          field: "body",
          missingId: "nested\\reference",
          expectedPath: "Packs/references/<invalid>.md",
          message: "Unsafe reference id path segment \"nested\\reference\"."
        )
      )
    )
  }

  @Test
  func validateRejectsEscapingEssentialSymlink() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(
      at: root.appendingPathComponent("Sessions/senior-swiftui-engineer_apply-style.session.json")
    )

    let outsideURL = try makeTempDirectory().appendingPathComponent("outside-essential.md")
    try "# Outside\n".write(
      to: outsideURL,
      atomically: true,
      encoding: .utf8
    )

    let symlinkURL = root.appendingPathComponent("Packs/essentials/linked-essential.md")
    try FileManager.default.createSymbolicLink(
      at: symlinkURL,
      withDestinationURL: outsideURL
    )

    let kitURL = root.appendingPathComponent("Packs/kits/swiftui-style.kit.json")
    let kit = try JSONDecoder().decode(Kit.self, from: Data(contentsOf: kitURL))
    let updatedKit = Kit(
      id: kit.id,
      version: kit.version,
      name: kit.name,
      summary: kit.summary,
      essentialIds: ["linked-essential"],
      referenceIds: kit.referenceIds,
      intentTemplateIds: kit.intentTemplateIds,
      skillIds: kit.skillIds
    )

    try encodeSortedJSON(updatedKit).write(to: kitURL, options: .atomic)

    let result = try Validator.validate(root: root)

    #expect(
      result.errors.contains(
        ValidationError(
          entityType: .kit,
          entityId: "swiftui-style",
          field: "essentialIds",
          missingId: "linked-essential",
          expectedPath: "Packs/essentials/linked-essential.md",
          message: "Unsafe essential file path for id \"linked-essential\"."
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
  func validateRejectsEssentialPathWhenItIsAFile() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    let packsURL = root.appendingPathComponent("Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )
    try Data("not a directory".utf8).write(to: packsURL.appendingPathComponent("essentials"))

    let result = try Validator.validate(root: root)

    #expect(result.counts == .zero)
    #expect(
      result.errors == [
        ValidationError(
          entityType: .essentials,
          entityId: nil,
          field: "file",
          missingId: nil,
          expectedPath: "Packs/essentials",
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
  func validateIntentParameterConstraintRequiresMultipleParameters() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)

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
