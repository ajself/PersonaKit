import Foundation
import MCP

enum MCPToolName: String, CaseIterable {
  case validate = "personakit_validate"
  case export = "personakit_export"
  case graph = "personakit_graph"

  var description: String {
    switch self {
    case .validate:
      return "Validate PersonaKit packs and report errors."
    case .export:
      return "Assemble Persona+Kits+Directive into a single Markdown prompt."
    case .graph:
      return "Print a readable dependency graph for a session."
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
    }
  }

  var annotations: Tool.Annotations {
    return Tool.Annotations(
      readOnlyHint: true,
      openWorldHint: false
    )
  }
}

struct MCPToolArguments: Equatable {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

enum MCPToolArgumentError: Error, LocalizedError, Equatable {
  case missing(String)
  case invalidType(String)

  var errorDescription: String? {
    switch self {
    case .missing(let name):
      return "Missing required argument: \(name)"
    case .invalidType(let name):
      if name == "kits" {
        return
          "Invalid argument type for \(name); expected array of strings or comma-separated string."
      }
      return "Invalid argument type for \(name); expected string."
    }
  }
}

enum MCPToolArgumentParser {
  static func parse(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    let personaId = try requireString(arguments, name: "personaId")
    let directiveId = try requireString(arguments, name: "directiveId")
    let kitOverrides = try parseKitOverrides(arguments?["kits"])
    return MCPToolArguments(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides
    )
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

struct MCPToolService: Sendable {
  let scopes: ScopeSet

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

  func callTool(name: String, arguments: [String: Value]?) throws -> CallTool.Result {
    guard let tool = MCPToolName(rawValue: name) else {
      throw MCPError.invalidParams("Unknown tool name: \(name)")
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
    }
  }

  private func parseSessionArguments(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    do {
      return try MCPToolArgumentParser.parse(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(error.localizedDescription)
    }
  }

  private func validateTool(arguments: [String: Value]?) throws -> String {
    if let arguments, !arguments.isEmpty {
      throw MCPError.invalidParams("personakit_validate does not accept arguments.")
    }
    let result = try Validator.validate(scopes: scopes)
    let payload = ValidationToolOutput(result: result)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(payload)
    guard let text = String(data: data, encoding: .utf8) else {
      throw MCPError.internalError("Failed to encode validation output.")
    }
    return text + "\n"
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
