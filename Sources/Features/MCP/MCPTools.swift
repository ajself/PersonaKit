import ContextCore
import Foundation
import MCP

/// Supported tool names exposed by the PersonaKit MCP server.
enum MCPToolName: String, CaseIterable {
  case compareEntities = "personakit_compare_entities"
  case explainEntity = "personakit_explain_entity"
  case export = "personakit_export"
  case graph = "personakit_graph"
  case recommendSession = "personakit_recommend_session"
  case resolveSessionRef = "personakit_resolve_session_ref"
  case traceSession = "personakit_trace_session"
  case validate = "personakit_validate"

  var description: String {
    switch self {
    case .compareEntities:
      return "Compare two PersonaKit entities of the same type and report deterministic differences."
    case .explainEntity:
      return "Explain a PersonaKit entity with key fields and relationship edges."
    case .export:
      return "Assemble Persona+Kits+Directive into a single Markdown prompt."
    case .graph:
      return "Print a readable dependency graph for a session."
    case .recommendSession:
      return "Recommend sessions for a goal using deterministic ranking."
    case .resolveSessionRef:
      return "Resolve a session reference supplied as either a session id or a session-file path."
    case .traceSession:
      return "Trace a session into persona/directive/kits/intents/skills/essentials edges."
    case .validate:
      return "Validate PersonaKit packs and report errors."
    }
  }

  var inputSchema: Value {
    switch self {
    case .validate:
      return [
        "type": "object",
        "properties": Value.object([:]),
        "additionalProperties": false,
      ]
    case .export, .graph:
      let properties: Value = [
        "personaId": [
          "type": "string",
          "description": "Persona id",
        ],
        "directiveId": [
          "type": "string",
          "description": "Directive id",
        ],
        "kits": [
          "type": "array",
          "description": "Optional kit id overrides",
          "items": [
            "type": "string"
          ],
        ],
      ]
      return [
        "type": "object",
        "properties": properties,
        "required": ["personaId", "directiveId"],
        "additionalProperties": false,
      ]
    case .explainEntity:
      return [
        "type": "object",
        "properties": [
          "entityType": [
            "type": "string",
            "enum": Value.array(MCPEntityType.allCases.map { .string($0.rawValue) }),
            "description": "Entity type to explain",
          ],
          "id": [
            "type": "string",
            "description": "Entity id",
          ],
        ],
        "required": ["entityType", "id"],
        "additionalProperties": false,
      ]
    case .compareEntities:
      return [
        "type": "object",
        "properties": [
          "entityType": [
            "type": "string",
            "enum": Value.array(MCPEntityType.allCases.map { .string($0.rawValue) }),
            "description": "Entity type shared by both inputs",
          ],
          "leftId": [
            "type": "string",
            "description": "Left entity id",
          ],
          "rightId": [
            "type": "string",
            "description": "Right entity id",
          ],
        ],
        "required": ["entityType", "leftId", "rightId"],
        "additionalProperties": false,
      ]
    case .recommendSession:
      return [
        "type": "object",
        "properties": [
          "goal": [
            "type": "string",
            "description": "Natural-language goal to match against session metadata",
          ],
          "limit": [
            "type": "integer",
            "description": "Optional max recommendations (1-20), default 3",
          ],
        ],
        "required": ["goal"],
        "additionalProperties": false,
      ]
    case .resolveSessionRef:
      return [
        "type": "object",
        "properties": [
          "sessionRef": [
            "type": "string",
            "description": "Session id or session-file path",
          ],
        ],
        "required": ["sessionRef"],
        "additionalProperties": false,
      ]
    case .traceSession:
      return [
        "type": "object",
        "properties": [
          "sessionId": [
            "type": "string",
            "description": "Session id",
          ],
        ],
        "required": ["sessionId"],
        "additionalProperties": false,
      ]
    }
  }

  var annotations: Tool.Annotations {
    return Tool.Annotations(
      readOnlyHint: true,
      openWorldHint: false
    )
  }
}

/// Supported explain/compare entity types.
enum MCPEntityType: String, CaseIterable {
  case persona
  case directive
  case kit
  case session
  case intent
  case skill
  case essential
}

/// Parsed and normalized session arguments for export/graph tool calls.
struct MCPToolArguments: Equatable {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

struct MCPEntityArguments: Equatable {
  let entityType: MCPEntityType
  let id: String
}

struct MCPCompareArguments: Equatable {
  let entityType: MCPEntityType
  let leftId: String
  let rightId: String
}

struct MCPRecommendArguments: Equatable {
  let goal: String
  let limit: Int
}

struct MCPTraceArguments: Equatable {
  let sessionId: String
}

struct MCPResolveSessionArguments: Equatable {
  let sessionRef: String
}

/// Tool argument parsing failures returned as MCP invalid-params errors.
enum MCPToolArgumentError: Error, LocalizedError, Equatable {
  case missing(String)
  case invalidType(String)
  case invalidValue(String, String)

  var errorDescription: String? {
    switch self {
    case .missing(let name):
      return "Missing required argument: \(name)"
    case .invalidType(let name):
      if name == "kits" {
        return
          "Invalid argument type for \(name); expected array of strings or comma-separated string."
      }
      if name == "limit" {
        return "Invalid argument type for \(name); expected integer or numeric string."
      }
      return "Invalid argument type for \(name); expected string."
    case .invalidValue(let name, let message):
      return "Invalid value for \(name): \(message)"
    }
  }
}

/// Decoder for tool call arguments.
enum MCPToolArgumentParser {
  /// Parses and validates common session arguments for MCP tool calls.
  static func parseSession(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    let personaId = try requireString(arguments, name: "personaId")
    let directiveId = try requireString(arguments, name: "directiveId")
    let kitOverrides = try parseKitOverrides(arguments?["kits"])
    return MCPToolArguments(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides
    )
  }

  static func parseEntity(_ arguments: [String: Value]?) throws -> MCPEntityArguments {
    let entityType = try parseEntityType(arguments, name: "entityType")
    let id = try requireString(arguments, name: "id")
    return MCPEntityArguments(entityType: entityType, id: id)
  }

  static func parseCompare(_ arguments: [String: Value]?) throws -> MCPCompareArguments {
    let entityType = try parseEntityType(arguments, name: "entityType")
    let leftId = try requireString(arguments, name: "leftId")
    let rightId = try requireString(arguments, name: "rightId")
    return MCPCompareArguments(entityType: entityType, leftId: leftId, rightId: rightId)
  }

  static func parseRecommend(_ arguments: [String: Value]?) throws -> MCPRecommendArguments {
    let goal = try requireString(arguments, name: "goal")
    let limit = try parseLimit(arguments?["limit"])
    return MCPRecommendArguments(goal: goal, limit: limit)
  }

  static func parseTrace(_ arguments: [String: Value]?) throws -> MCPTraceArguments {
    return MCPTraceArguments(sessionId: try requireString(arguments, name: "sessionId"))
  }

  static func parseResolveSession(_ arguments: [String: Value]?) throws -> MCPResolveSessionArguments {
    return MCPResolveSessionArguments(sessionRef: try requireString(arguments, name: "sessionRef"))
  }

  private static func requireString(_ arguments: [String: Value]?, name: String) throws -> String {
    guard let value = arguments?[name] else {
      throw MCPToolArgumentError.missing(name)
    }
    guard let stringValue = value.stringValue else {
      throw MCPToolArgumentError.invalidType(name)
    }
    let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw MCPToolArgumentError.missing(name)
    }
    return trimmed
  }

  private static func parseEntityType(_ arguments: [String: Value]?, name: String) throws -> MCPEntityType {
    let value = try requireString(arguments, name: name)
    guard let entityType = MCPEntityType(rawValue: value) else {
      throw MCPToolArgumentError.invalidValue(name, "expected one of: \(MCPEntityType.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    return entityType
  }

  private static func parseLimit(_ value: Value?) throws -> Int {
    guard let value else {
      return 3
    }

    let parsed: Int?
    if let intValue = value.intValue {
      parsed = intValue
    } else if let stringValue = value.stringValue {
      parsed = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      parsed = nil
    }

    guard let parsed else {
      throw MCPToolArgumentError.invalidType("limit")
    }

    guard (1...20).contains(parsed) else {
      throw MCPToolArgumentError.invalidValue("limit", "must be between 1 and 20")
    }

    return parsed
  }

  private static func parseKitOverrides(_ value: Value?) throws -> [String] {
    guard let value else {
      return []
    }
    if let stringValue = value.stringValue {
      return parseKitList(stringValue)
    }
    if let arrayValue = value.arrayValue {
      var parsed: [String] = []
      var sawNonString = false
      for item in arrayValue {
        guard let stringValue = item.stringValue else {
          sawNonString = true
          continue
        }
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          parsed.append(trimmed)
        }
      }
      if sawNonString {
        throw MCPToolArgumentError.invalidType("kits")
      }
      return parsed
    }
    throw MCPToolArgumentError.invalidType("kits")
  }

  private static func parseKitList(_ value: String) -> [String] {
    return
      value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

/// MCP tool handler service for validate, export, graph, and discussion operations.
struct MCPToolService: Sendable {
  let scopes: ScopeSet

  /// Returns tool definitions in deterministic name order.
  func listTools() -> [Tool] {
    return MCPToolName.allCases
      .sorted { $0.rawValue < $1.rawValue }
      .map { tool in
        Tool(
          name: tool.rawValue,
          description: tool.description,
          inputSchema: tool.inputSchema,
          annotations: tool.annotations
        )
      }
  }

  /// Executes an MCP tool call and returns a text-only response payload.
  func callTool(name: String, arguments: [String: Value]?) throws -> CallTool.Result {
    guard let tool = MCPToolName(rawValue: name) else {
      throw MCPError.invalidParams(
        withRecoveryHint(
          "Unknown tool name: \(name)",
          hint: "Call list_tools and retry using one of the advertised tool names."
        )
      )
    }

    switch tool {
    case .validate:
      let output = try validateTool(arguments: arguments)
      return CallTool.Result(content: [.text(output)])
    case .export:
      let input = try parseSessionArguments(arguments)
      let output = try exportTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .graph:
      let input = try parseSessionArguments(arguments)
      let output = try graphTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .explainEntity:
      let input = try parseEntityArguments(arguments)
      let output = try explainEntityTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .compareEntities:
      let input = try parseCompareArguments(arguments)
      let output = try compareEntitiesTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .recommendSession:
      let input = try parseRecommendArguments(arguments)
      let output = try recommendSessionTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .resolveSessionRef:
      let input = try parseResolveSessionArguments(arguments)
      let output = try resolveSessionRefTool(input: input)
      return CallTool.Result(content: [.text(output)])
    case .traceSession:
      let input = try parseTraceArguments(arguments)
      let output = try traceSessionTool(input: input)
      return CallTool.Result(content: [.text(output)])
    }
  }

  private func parseSessionArguments(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    do {
      return try MCPToolArgumentParser.parseSession(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide personaId and directiveId as non-empty strings, plus optional kits."
        )
      )
    }
  }

  private func parseEntityArguments(_ arguments: [String: Value]?) throws -> MCPEntityArguments {
    do {
      return try MCPToolArgumentParser.parseEntity(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide entityType and id as strings. Use list_resources to discover ids."
        )
      )
    }
  }

  private func parseCompareArguments(_ arguments: [String: Value]?) throws -> MCPCompareArguments {
    do {
      return try MCPToolArgumentParser.parseCompare(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide entityType plus leftId/rightId as strings for the same entity type."
        )
      )
    }
  }

  private func parseRecommendArguments(_ arguments: [String: Value]?) throws -> MCPRecommendArguments {
    do {
      return try MCPToolArgumentParser.parseRecommend(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide goal as a non-empty string and optional limit between 1 and 20."
        )
      )
    }
  }

  private func parseTraceArguments(_ arguments: [String: Value]?) throws -> MCPTraceArguments {
    do {
      return try MCPToolArgumentParser.parseTrace(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide sessionId as a non-empty string. Use catalog sessions to discover ids."
        )
      )
    }
  }

  private func parseResolveSessionArguments(
    _ arguments: [String: Value]?
  ) throws -> MCPResolveSessionArguments {
    do {
      return try MCPToolArgumentParser.parseResolveSession(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Provide sessionRef as a non-empty session id or session-file path."
        )
      )
    }
  }

  private func validateTool(arguments: [String: Value]?) throws -> String {
    if let arguments, !arguments.isEmpty {
      throw MCPError.invalidParams(
        withRecoveryHint(
          "personakit_validate does not accept arguments.",
          hint: "Call personakit_validate with an empty argument object."
        )
      )
    }
    let result = try Validator.validate(scopes: scopes)
    let payload = ValidationToolOutput(result: result)
    return try encodeToolJSON(payload)
  }

  private func exportTool(input: MCPToolArguments) throws -> String {
    do {
      let output = try SessionExporter.export(
        scopes: scopes,
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides
      )
      return output + "\n"
    } catch let error as ExportError {
      throw MCPError.invalidParams(formatExportError(error))
    }
  }

  private func graphTool(input: MCPToolArguments) throws -> String {
    do {
      let registry = try Registry.load(scopes: scopes)
      let definition = SessionDefinition(
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides.isEmpty ? nil : input.kitOverrides
      )
      let resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
      let output = GraphPrinter.render(
        resolvedSession: resolved,
        kitOverrides: input.kitOverrides
      )
      return output + "\n"
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(formatRegistryErrors(error.errors))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(formatResolutionErrors(error.errors))
    }
  }

  private func explainEntityTool(input: MCPEntityArguments) throws -> String {
    let registry = try loadRegistry()

    switch input.entityType {
    case .persona:
      guard let persona = registry.personasById[input.id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .persona, id: input.id))
      }
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: PersonaExplainData(
            name: persona.name,
            summary: persona.summary,
            defaultKitIds: uniqueSorted(persona.defaultKitIds),
            allowedSkillIds: uniqueSorted(persona.allowedSkillIds),
            forbiddenSkillIds: uniqueSorted(persona.forbiddenSkillIds),
            responsibilitiesCount: persona.responsibilities.count,
            valuesCount: persona.values.count,
            nonGoalsCount: persona.nonGoals.count
          )
        )
      )
    case .directive:
      guard let directive = registry.directivesById[input.id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .directive, id: input.id))
      }
      let reviewStepCount = directive.steps.filter { $0.requiresReview == true }.count
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: DirectiveExplainData(
            title: directive.title,
            goal: directive.goal,
            requiredIntentIds: uniqueSorted(directive.requiresIntentTemplateIds),
            requiredSkillIds: uniqueSorted(directive.requiresSkillIds),
            stepsCount: directive.steps.count,
            reviewStepCount: reviewStepCount
          )
        )
      )
    case .kit:
      guard let kit = registry.kitsById[input.id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .kit, id: input.id))
      }
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: KitExplainData(
            name: kit.name,
            summary: kit.summary,
            essentialIds: uniqueSorted(kit.essentialIds),
            intentTemplateIds: uniqueSorted(kit.intentTemplateIds ?? []),
            skillIds: uniqueSorted(kit.skillIds ?? [])
          )
        )
      )
    case .intent:
      guard let intent = registry.intentTemplatesById[input.id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .intent, id: input.id))
      }
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: IntentExplainData(
            name: intent.name,
            description: intent.description,
            parameterConstraints: intent.parameterConstraints?.map(parameterConstraintSummary) ?? [],
            includesEssentialIds: uniqueSorted(intent.includesEssentialIds),
            requiresSkillIds: uniqueSorted(intent.requiresSkillIds),
            riskLevel: intent.risk.level,
            requiresHumanReview: intent.risk.requiresHumanReview
          )
        )
      )
    case .skill:
      guard let skill = registry.skillsById[input.id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .skill, id: input.id))
      }
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: SkillExplainData(
            name: skill.name,
            description: skill.description,
            providedBy: uniqueSorted(skill.providedBy),
            riskLevel: skill.risk.level,
            requiresHumanReview: skill.risk.requiresHumanReview,
            notesCount: skill.notes.count
          )
        )
      )
    case .session:
      let session = try loadSession(id: input.id)
      let personaExists = registry.personasById[session.personaId] != nil
      let directiveExists = registry.directivesById[session.directiveId] != nil
      let missingKits = uniqueSorted((session.kitOverrides ?? []).filter { registry.kitsById[$0] == nil })
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: SessionExplainData(
            personaId: session.personaId,
            directiveId: session.directiveId,
            kitOverrides: uniqueSorted(session.kitOverrides ?? []),
            personaExists: personaExists,
            directiveExists: directiveExists,
            missingKitOverrides: missingKits
          )
        )
      )
    case .essential:
      guard let fileURL = resolveEssentialURL(id: input.id, scopes: scopes, fileManager: .default)
      else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .essential, id: input.id))
      }
      let text: String
      do {
        text = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw MCPError.internalError("Failed to read essential \(input.id).")
      }
      return try encodeToolJSON(
        ExplainPayload(
          entityType: input.entityType.rawValue,
          id: input.id,
          data: EssentialExplainData(
            resolvedPath: fileURL.path,
            lineCount: lineCount(text),
            byteCount: text.utf8.count
          )
        )
      )
    }
  }

  private func compareEntitiesTool(input: MCPCompareArguments) throws -> String {
    let registry = try loadRegistry()
    let left = try comparableSnapshot(type: input.entityType, id: input.leftId, registry: registry)
    let right = try comparableSnapshot(type: input.entityType, id: input.rightId, registry: registry)

    let scalarKeys = Set(left.scalars.keys).union(right.scalars.keys).sorted()
    let scalarMatches = scalarKeys.filter { left.scalars[$0] == right.scalars[$0] }
    let scalarDifferences = scalarKeys.compactMap { key -> CompareScalarDifference? in
      let leftValue = left.scalars[key] ?? ""
      let rightValue = right.scalars[key] ?? ""
      guard leftValue != rightValue else {
        return nil
      }
      return CompareScalarDifference(field: key, left: leftValue, right: rightValue)
    }

    let listKeys = Set(left.lists.keys).union(right.lists.keys).sorted()
    let listMatches = listKeys.filter { left.lists[$0] == right.lists[$0] }
    let listDifferences = listKeys.compactMap { key -> CompareListDifference? in
      let leftValues = left.lists[key] ?? []
      let rightValues = right.lists[key] ?? []
      guard leftValues != rightValues else {
        return nil
      }

      let leftSet = Set(leftValues)
      let rightSet = Set(rightValues)
      let shared = leftSet.intersection(rightSet).sorted()
      let onlyLeft = leftSet.subtracting(rightSet).sorted()
      let onlyRight = rightSet.subtracting(leftSet).sorted()

      return CompareListDifference(
        field: key,
        shared: shared,
        onlyLeft: onlyLeft,
        onlyRight: onlyRight
      )
    }

    return try encodeToolJSON(
      ComparePayload(
        entityType: input.entityType.rawValue,
        leftId: input.leftId,
        rightId: input.rightId,
        scalarMatches: scalarMatches,
        scalarDifferences: scalarDifferences,
        listMatches: listMatches,
        listDifferences: listDifferences
      )
    )
  }

  private func recommendSessionTool(input: MCPRecommendArguments) throws -> String {
    let registry = try loadRegistry()
    let sessions = try listSessions(scopes: scopes, fileManager: .default)

    guard !sessions.isEmpty else {
      throw MCPError.invalidParams(
        withRecoveryHint(
          "No session files found in active scopes.",
          hint: "Create at least one Sessions/*.session.json file in the active PersonaKit scope."
        )
      )
    }

    let goalTerms = tokenSet(input.goal)
    let recommendations = sessions.compactMap { session -> SessionRecommendation? in
      guard let persona = registry.personasById[session.personaId],
        let directive = registry.directivesById[session.directiveId]
      else {
        return nil
      }

      let personaTerms = matchedTerms(
        goalTerms: goalTerms,
        text: [
          persona.id,
          persona.name,
          persona.summary,
          persona.responsibilities.joined(separator: " "),
          persona.values.joined(separator: " "),
        ].joined(separator: " ")
      )

      let directiveTerms = matchedTerms(
        goalTerms: goalTerms,
        text: [
          directive.id,
          directive.title,
          directive.goal,
          directive.acceptanceCriteria.joined(separator: " "),
          directive.steps.map(\.text).joined(separator: " "),
        ].joined(separator: " ")
      )

      let sessionTerms = matchedTerms(goalTerms: goalTerms, text: session.id)

      let score = personaTerms.count * 3 + directiveTerms.count * 2 + sessionTerms.count

      return SessionRecommendation(
        sessionId: session.id,
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: uniqueSorted(session.kitOverrides ?? []),
        score: score,
        matchedGoalTerms: uniqueSorted(personaTerms + directiveTerms + sessionTerms),
        termMatches: SessionRecommendationTermMatches(
          persona: personaTerms,
          directive: directiveTerms,
          session: sessionTerms
        )
      )
    }
      .sorted {
        if $0.score != $1.score {
          return $0.score > $1.score
        }
        return $0.sessionId < $1.sessionId
      }

    let selected = Array(recommendations.prefix(input.limit))

    return try encodeToolJSON(
      SessionRecommendationPayload(
        goal: input.goal,
        goalTerms: goalTerms,
        consideredSessions: sessions.map(\.id).sorted(),
        policy: SessionRecommendationPolicy(),
        recommendations: selected
      )
    )
  }

  private func resolveSessionRefTool(input: MCPResolveSessionArguments) throws -> String {
    let resolved: ResolvedSessionReference
    do {
      resolved = try SessionReferenceResolver.resolve(
        scopes: scopes,
        sessionRef: input.sessionRef
      )
    } catch let error as SessionReferenceError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Use a valid session id from personakit://catalog/sessions or a path under Sessions/*.session.json in the active PersonaKit scope."
        )
      )
    } catch let error as SessionFileError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Use a valid session id from personakit://catalog/sessions or a session-file path under the active PersonaKit scope."
        )
      )
    }

    return try encodeToolJSON(
      SessionReferenceResolutionPayload(
        inputRef: input.sessionRef,
        sourceRefType: resolved.sourceRefType.rawValue,
        normalizedSessionId: resolved.sessionId,
        resolvedPath: resolved.resolvedPath,
        scopeRootPath: resolved.scopeRootPath,
        personaId: resolved.session.personaId,
        directiveId: resolved.session.directiveId,
        kitOverrides: uniqueSorted(resolved.session.kitOverrides ?? [])
      )
    )
  }

  private func traceSessionTool(input: MCPTraceArguments) throws -> String {
    let session = try loadSession(id: input.sessionId)
    let registry = try loadRegistry()

    let definition = SessionDefinition(
      personaId: session.personaId,
      directiveId: session.directiveId,
      kitOverrides: (session.kitOverrides ?? []).isEmpty ? nil : session.kitOverrides
    )

    let resolved: ResolvedSession
    do {
      resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(formatResolutionErrors(error.errors))
    }

    let appliedKits = resolved.kits.sorted { $0.id < $1.id }
    let kitToEssentials = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: uniqueSorted($0.essentialIds))
    }
    let kitToIntents = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: uniqueSorted($0.intentTemplateIds ?? []))
    }
    let kitToSkills = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: uniqueSorted($0.skillIds ?? []))
    }
    let intentToEssentials = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        SessionTraceEdgeMap(sourceId: $0.id, targetIds: uniqueSorted($0.includesEssentialIds))
      }
    let intentToSkills = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        SessionTraceEdgeMap(sourceId: $0.id, targetIds: uniqueSorted($0.requiresSkillIds))
      }

    return try encodeToolJSON(
      SessionTracePayload(
        session: SessionTraceSession(
          id: session.id,
          personaId: session.personaId,
          directiveId: session.directiveId,
          kitOverrides: uniqueSorted(session.kitOverrides ?? [])
        ),
        resolved: SessionTraceResolved(
          personaId: resolved.persona.id,
          directiveId: resolved.directive.id,
          kitIds: resolved.kits.map(\.id).sorted(),
          essentialIds: resolved.essentials.map(\.id).sorted(),
          intentIds: resolved.intents.map(\.id).sorted(),
          skillIds: resolved.skills.map(\.id).sorted()
        ),
        edges: SessionTraceEdges(
          personaDefaultKitIds: uniqueSorted(resolved.persona.defaultKitIds),
          sessionKitOverrideIds: uniqueSorted(session.kitOverrides ?? []),
          directiveIntentIds: uniqueSorted(resolved.directive.requiresIntentTemplateIds),
          directiveSkillIds: uniqueSorted(resolved.directive.requiresSkillIds),
          kitToEssentials: kitToEssentials,
          kitToIntents: kitToIntents,
          kitToSkills: kitToSkills,
          intentToEssentials: intentToEssentials,
          intentToSkills: intentToSkills
        )
      )
    )
  }

  private func comparableSnapshot(
    type: MCPEntityType,
    id: String,
    registry: Registry
  ) throws -> EntityComparableSnapshot {
    switch type {
    case .persona:
      guard let persona = registry.personasById[id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .persona, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": persona.id,
          "name": persona.name,
          "summary": persona.summary,
          "version": persona.version,
        ],
        lists: [
          "defaultKitIds": uniqueSorted(persona.defaultKitIds),
          "allowedSkillIds": uniqueSorted(persona.allowedSkillIds),
          "forbiddenSkillIds": uniqueSorted(persona.forbiddenSkillIds),
          "values": uniqueSorted(persona.values),
          "nonGoals": uniqueSorted(persona.nonGoals),
        ]
      )
    case .directive:
      guard let directive = registry.directivesById[id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .directive, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": directive.id,
          "title": directive.title,
          "goal": directive.goal,
          "version": directive.version,
        ],
        lists: [
          "requiresIntentTemplateIds": uniqueSorted(directive.requiresIntentTemplateIds),
          "requiresSkillIds": uniqueSorted(directive.requiresSkillIds),
          "acceptanceCriteria": uniqueSorted(directive.acceptanceCriteria),
        ]
      )
    case .kit:
      guard let kit = registry.kitsById[id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .kit, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": kit.id,
          "name": kit.name,
          "summary": kit.summary,
          "version": kit.version,
        ],
        lists: [
          "essentialIds": uniqueSorted(kit.essentialIds),
          "intentTemplateIds": uniqueSorted(kit.intentTemplateIds ?? []),
          "skillIds": uniqueSorted(kit.skillIds ?? []),
        ]
      )
    case .session:
      let session = try loadSession(id: id)
      return EntityComparableSnapshot(
        scalars: [
          "id": session.id,
          "personaId": session.personaId,
          "directiveId": session.directiveId,
        ],
        lists: [
          "kitOverrides": uniqueSorted(session.kitOverrides ?? []),
        ]
      )
    case .intent:
      guard let intent = registry.intentTemplatesById[id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .intent, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": intent.id,
          "name": intent.name,
          "description": intent.description,
          "riskLevel": intent.risk.level,
          "requiresHumanReview": String(intent.risk.requiresHumanReview),
          "version": intent.version,
        ],
        lists: [
          "parameterConstraints": uniqueSorted(
            (intent.parameterConstraints ?? []).map(parameterConstraintSummary)
          ),
          "includesEssentialIds": uniqueSorted(intent.includesEssentialIds),
          "requiresSkillIds": uniqueSorted(intent.requiresSkillIds),
        ]
      )
    case .skill:
      guard let skill = registry.skillsById[id] else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .skill, id: id))
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": skill.id,
          "name": skill.name,
          "description": skill.description,
          "riskLevel": skill.risk.level,
          "requiresHumanReview": String(skill.risk.requiresHumanReview),
          "version": skill.version,
        ],
        lists: [
          "providedBy": uniqueSorted(skill.providedBy),
          "notes": uniqueSorted(skill.notes),
        ]
      )
    case .essential:
      guard let fileURL = resolveEssentialURL(id: id, scopes: scopes, fileManager: .default)
      else {
        throw MCPError.invalidParams(missingEntityMessage(entityType: .essential, id: id))
      }
      let content: String
      do {
        content = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw MCPError.internalError("Failed to read essential \(id).")
      }
      return EntityComparableSnapshot(
        scalars: [
          "id": id,
          "resolvedPath": fileURL.path,
          "lineCount": String(lineCount(content)),
          "byteCount": String(content.utf8.count),
        ],
        lists: [:]
      )
    }
  }

  private func loadRegistry() throws -> Registry {
    do {
      return try Registry.load(scopes: scopes)
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(formatRegistryErrors(error.errors))
    }
  }

  private func loadSession(id: String) throws -> SessionFile {
    do {
      return try SessionFileLoader.load(scopes: scopes, sessionId: id)
    } catch let error as SessionFileError {
      throw MCPError.invalidParams(
        withRecoveryHint(
          error.localizedDescription,
          hint: "Read personakit://catalog/sessions to list valid ids, then retry with one session id."
        )
      )
    }
  }
}

private struct ValidationToolOutput: Codable, Equatable {
  struct Counts: Codable, Equatable {
    let personas: Int
    let kits: Int
    let directives: Int
    let intents: Int
    let skills: Int
    let essentials: Int
  }

  let ok: Bool
  let counts: Counts
  let errors: [String]

  init(result: ValidationResult) {
    self.ok = result.errors.isEmpty
    self.counts = Counts(
      personas: result.counts.personas,
      kits: result.counts.kits,
      directives: result.counts.directives,
      intents: result.counts.intents,
      skills: result.counts.skills,
      essentials: result.counts.essentials
    )
    self.errors = result.errors.map { $0.lineDescription() }
  }
}

private struct ExplainPayload<DataPayload: Encodable>: Encodable {
  let schemaVersion: Int = 1
  let entityType: String
  let id: String
  let data: DataPayload
}

private struct PersonaExplainData: Encodable {
  let name: String
  let summary: String
  let defaultKitIds: [String]
  let allowedSkillIds: [String]
  let forbiddenSkillIds: [String]
  let responsibilitiesCount: Int
  let valuesCount: Int
  let nonGoalsCount: Int
}

private struct DirectiveExplainData: Encodable {
  let title: String
  let goal: String
  let requiredIntentIds: [String]
  let requiredSkillIds: [String]
  let stepsCount: Int
  let reviewStepCount: Int
}

private struct KitExplainData: Encodable {
  let name: String
  let summary: String
  let essentialIds: [String]
  let intentTemplateIds: [String]
  let skillIds: [String]
}

private struct IntentExplainData: Encodable {
  let name: String
  let description: String
  let parameterConstraints: [String]
  let includesEssentialIds: [String]
  let requiresSkillIds: [String]
  let riskLevel: String
  let requiresHumanReview: Bool
}

private struct SkillExplainData: Encodable {
  let name: String
  let description: String
  let providedBy: [String]
  let riskLevel: String
  let requiresHumanReview: Bool
  let notesCount: Int
}

private struct SessionExplainData: Encodable {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
  let personaExists: Bool
  let directiveExists: Bool
  let missingKitOverrides: [String]
}

private struct EssentialExplainData: Encodable {
  let resolvedPath: String
  let lineCount: Int
  let byteCount: Int
}

private func parameterConstraintSummary(_ constraint: IntentTemplate.ParameterConstraint) -> String {
  "\(constraint.kind):" + constraint.parameterNames.joined(separator: ",")
}

private struct EntityComparableSnapshot {
  let scalars: [String: String]
  let lists: [String: [String]]
}

private struct ComparePayload: Encodable {
  let schemaVersion: Int = 1
  let entityType: String
  let leftId: String
  let rightId: String
  let scalarMatches: [String]
  let scalarDifferences: [CompareScalarDifference]
  let listMatches: [String]
  let listDifferences: [CompareListDifference]
}

private struct CompareScalarDifference: Encodable {
  let field: String
  let left: String
  let right: String
}

private struct CompareListDifference: Encodable {
  let field: String
  let shared: [String]
  let onlyLeft: [String]
  let onlyRight: [String]
}

private struct SessionRecommendationPolicy: Encodable {
  let scoringVersion: Int = 1
  let weights: [String: Int] = [
    "personaTermMatch": 3,
    "directiveTermMatch": 2,
    "sessionIdTermMatch": 1,
  ]
  let tieBreakers: [String] = [
    "higherScoreFirst",
    "sessionIdAscending",
  ]
}

private struct SessionRecommendationTermMatches: Encodable {
  let persona: [String]
  let directive: [String]
  let session: [String]
}

private struct SessionRecommendation: Encodable {
  let sessionId: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
  let score: Int
  let matchedGoalTerms: [String]
  let termMatches: SessionRecommendationTermMatches
}

private struct SessionRecommendationPayload: Encodable {
  let schemaVersion: Int = 1
  let goal: String
  let goalTerms: [String]
  let consideredSessions: [String]
  let policy: SessionRecommendationPolicy
  let recommendations: [SessionRecommendation]
}

private struct SessionReferenceResolutionPayload: Encodable {
  let schemaVersion: Int = 1
  let inputRef: String
  let sourceRefType: String
  let normalizedSessionId: String
  let resolvedPath: String
  let scopeRootPath: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

private struct SessionTracePayload: Encodable {
  let schemaVersion: Int = 1
  let session: SessionTraceSession
  let resolved: SessionTraceResolved
  let edges: SessionTraceEdges
}

private struct SessionTraceSession: Encodable {
  let id: String
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

private struct SessionTraceResolved: Encodable {
  let personaId: String
  let directiveId: String
  let kitIds: [String]
  let essentialIds: [String]
  let intentIds: [String]
  let skillIds: [String]
}

private struct SessionTraceEdges: Encodable {
  let personaDefaultKitIds: [String]
  let sessionKitOverrideIds: [String]
  let directiveIntentIds: [String]
  let directiveSkillIds: [String]
  let kitToEssentials: [SessionTraceEdgeMap]
  let kitToIntents: [SessionTraceEdgeMap]
  let kitToSkills: [SessionTraceEdgeMap]
  let intentToEssentials: [SessionTraceEdgeMap]
  let intentToSkills: [SessionTraceEdgeMap]
}

private struct SessionTraceEdgeMap: Encodable {
  let sourceId: String
  let targetIds: [String]
}

private func encodeToolJSON<T: Encodable>(_ payload: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data: Data
  do {
    data = try encoder.encode(payload)
  } catch {
    throw MCPError.internalError("Failed to encode tool output.")
  }

  guard let text = String(data: data, encoding: .utf8) else {
    throw MCPError.internalError("Failed to encode tool output.")
  }

  return text + "\n"
}

private func formatExportError(_ error: ExportError) -> String {
  switch error {
  case .validationFailed(let result):
    var lines: [String] = [result.summary]
    lines.append(contentsOf: result.errors.map { $0.lineDescription() })
    return lines.joined(separator: "\n")
  case .resolutionFailed(let resolutionError):
    return formatResolutionErrors(resolutionError.errors)
  case .readFailed(let message):
    return "Error: \(message)"
  }
}

private func formatResolutionErrors(_ errors: [ResolverError]) -> String {
  return errors.map { formatResolutionError($0) }.joined(separator: "\n")
}

private func formatResolutionError(_ error: ResolverError) -> String {
  var parts: [String] = [
    error.sourceType.rawValue,
    error.sourceId,
    error.field + ":",
    error.message,
  ]
  if case .missingEssentialFile(_, _, _, let missingId, let expectedPath) = error {
    parts.append("missingId=\(missingId)")
    parts.append("expectedPath=\(expectedPath)")
  } else if case .missingKitId(_, _, _, let missingId) = error {
    parts.append("missingId=\(missingId)")
  } else if case .missingIntentId(_, _, _, let missingId) = error {
    parts.append("missingId=\(missingId)")
  } else if case .missingSkillId(_, _, _, let missingId) = error {
    parts.append("missingId=\(missingId)")
  } else if case .missingPersona(_, let missingId) = error {
    parts.append("missingId=\(missingId)")
  } else if case .missingDirective(_, let missingId) = error {
    parts.append("missingId=\(missingId)")
  }
  return parts.joined(separator: " ")
}

private func formatRegistryErrors(_ errors: [RegistryError]) -> String {
  return errors.map { formatRegistryError($0) }.joined(separator: "\n")
}

private func formatRegistryError(_ error: RegistryError) -> String {
  var parts: [String] = []
  parts.append(error.entityType.rawValue)
  if let id = error.id {
    parts.append(id)
  }
  if let relativePath = error.relativePath {
    parts.append(relativePath)
  }
  parts.append(error.message)
  return "Error: " + parts.joined(separator: " ")
}

private func withRecoveryHint(_ message: String, hint: String) -> String {
  return "\(message)\nRecovery: \(hint)"
}

private func missingEntityMessage(entityType: MCPEntityType, id: String) -> String {
  let catalogType: String
  switch entityType {
  case .persona:
    catalogType = "personas"
  case .directive:
    catalogType = "directives"
  case .kit:
    catalogType = "kits"
  case .session:
    catalogType = "sessions"
  case .intent:
    catalogType = "intents"
  case .skill:
    catalogType = "skills"
  case .essential:
    catalogType = "essentials"
  }
  return withRecoveryHint(
    "\(entityType.rawValue) not found: \(id)",
    hint: "Read personakit://catalog/\(catalogType) to list valid ids, then retry."
  )
}

private func uniqueSorted(_ ids: [String]) -> [String] {
  return Set(ids).sorted()
}

private func resolveEssentialURL(id: String, scopes: ScopeSet, fileManager: FileManager) -> URL? {
  let relativePath = "Packs/essentials/\(id).md"
  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(relativePath)
    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }
  return nil
}

private func lineCount(_ text: String) -> Int {
  if text.isEmpty {
    return 0
  }
  return text.split(separator: "\n", omittingEmptySubsequences: false).count
}

private func listSessions(scopes: ScopeSet, fileManager: FileManager) throws -> [SessionFile] {
  var sessionsById: [String: SessionFile] = [:]

  for root in scopes.resolutionOrder {
    let sessionsURL = root.appendingPathComponent("Sessions")
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: sessionsURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      continue
    }

    let files: [URL]
    do {
      files = try fileManager.contentsOfDirectory(
        at: sessionsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    } catch {
      throw MCPError.internalError("Failed to read Sessions directory.")
    }

    let sessionFiles =
      files
      .filter { $0.lastPathComponent.hasSuffix(".session.json") }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for file in sessionFiles {
      let id = file.deletingPathExtension().deletingPathExtension().lastPathComponent
      guard sessionsById[id] == nil else {
        continue
      }

      do {
        sessionsById[id] = try SessionFileLoader.load(root: root, sessionId: id, fileManager: fileManager)
      } catch {
        throw MCPError.internalError("Failed to decode session file \(id).session.json.")
      }
    }
  }

  return sessionsById.keys.sorted().compactMap { sessionsById[$0] }
}

private func tokenSet(_ text: String) -> [String] {
  let stopWords: Set<String> = [
    "a", "an", "and", "as", "at", "be", "by", "for", "from", "in", "into", "is", "it", "of",
    "on", "or", "that", "the", "to", "with", "without", "you", "your",
  ]

  let normalized = text.lowercased()
  let parts =
    normalized
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { $0.count >= 3 }
    .filter { !stopWords.contains($0) }

  return uniqueSorted(parts)
}

private func matchedTerms(goalTerms: [String], text: String) -> [String] {
  let haystack = text.lowercased()
  return goalTerms.filter { haystack.contains($0) }
}
