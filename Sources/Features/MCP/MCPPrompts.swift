import ContextCore
import Foundation
import MCP

/// Supported prompt names exposed by the PersonaKit MCP server.
enum MCPPromptName: String, CaseIterable {
  case sessionExport = "personakit.session.export"
  case sessionGraph = "personakit.session.graph"

  var description: String {
    switch self {
    case .sessionExport:
      return "Assemble Persona+Kits+Directive into a single Markdown prompt."
    case .sessionGraph:
      return "Print a readable dependency graph for a session."
    }
  }

  var arguments: [Prompt.Argument] {
    switch self {
    case .sessionExport:
      return [
        .init(name: "sessionId", description: "Optional session id"),
        .init(name: "personaId", description: "Persona id"),
        .init(name: "directiveId", description: "Directive id"),
        .init(name: "kits", description: "Comma-separated kit ids"),
        .init(name: "targetPaths", description: "Comma-separated target file paths"),
        .init(name: "referenceTags", description: "Comma-separated reference tags"),
      ]
    case .sessionGraph:
      return [
        .init(name: "sessionId", description: "Optional session id"),
        .init(name: "personaId", description: "Persona id"),
        .init(name: "directiveId", description: "Directive id"),
        .init(name: "kits", description: "Comma-separated kit ids"),
      ]
    }
  }
}

/// Parsed and normalized prompt input arguments.
struct MCPPromptArguments: Equatable {
  let selection: MCPSessionSelection
  let targetPaths: [String]
  let referenceTags: [String]

  var sessionId: String? {
    selection.sessionId
  }

  var personaId: String? {
    selection.personaId
  }

  var directiveId: String? {
    selection.directiveId
  }

  var kitOverrides: [String] {
    selection.kitOverrides
  }
}

/// Prompt argument parsing failures returned as MCP invalid-params errors.
enum MCPPromptArgumentError: Error, LocalizedError, Equatable {
  case missing(String)
  case invalidType(String)
  case invalidValue(String, String)

  init(_ error: MCPSessionSelectionError) {
    switch error {
    case .missing(let name):
      self = .missing(name)
    case .invalidValue(let name, let message):
      self = .invalidValue(name, message)
    }
  }

  var errorDescription: String? {
    switch self {
    case .missing(let name):
      return "Missing required argument: \(name)"
    case .invalidType(let name):
      return "Invalid argument type for \(name); expected string."
    case .invalidValue(let name, let message):
      return "Invalid value for \(name): \(message)"
    }
  }
}

/// Decoder for `GetPrompt` argument payloads.
enum MCPPromptArgumentParser {
  /// Parses required persona/directive values and optional kit overrides.
  static func parse(_ arguments: [String: Value]?) throws -> MCPPromptArguments {
    let sessionId = try parseOptionalString(arguments, name: "sessionId")
    let personaId = try parseOptionalString(arguments, name: "personaId")
    let directiveId = try parseOptionalString(arguments, name: "directiveId")
    let kitOverrides = try parseKitOverrides(arguments?["kits"])
    let targetPaths = try parseCSV(arguments?["targetPaths"], fieldName: "targetPaths")
    let referenceTags = try parseCSV(
      arguments?["referenceTags"],
      fieldName: "referenceTags"
    )

    let selection: MCPSessionSelection

    do {
      selection = try MCPSessionSelection.validate(
        sessionId: sessionId,
        personaId: personaId,
        directiveId: directiveId,
        kitOverrides: kitOverrides
      )
    } catch let error as MCPSessionSelectionError {
      throw MCPPromptArgumentError(error)
    }

    return MCPPromptArguments(
      selection: selection,
      targetPaths: targetPaths,
      referenceTags: referenceTags
    )
  }

  private static func parseOptionalString(_ arguments: [String: Value]?, name: String) throws -> String? {
    guard let value = arguments?[name] else {
      return nil
    }

    guard let stringValue = value.stringValue else {
      throw MCPPromptArgumentError.invalidType(name)
    }

    let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

    return trimmed.isEmpty ? nil : trimmed
  }

  private static func parseKitOverrides(_ value: Value?) throws -> [String] {
    try parseCSV(value, fieldName: "kits")
  }

  private static func parseCSV(_ value: Value?, fieldName: String) throws -> [String] {
    guard let value else {
      return []
    }

    guard let stringValue = value.stringValue else {
      throw MCPPromptArgumentError.invalidType(fieldName)
    }

    return
      stringValue
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

/// MCP prompt handler service for export and graph prompts.
struct MCPPromptService: Sendable {
  let scopes: ScopeSet

  /// Returns prompt definitions in deterministic name order.
  func listPrompts() -> [Prompt] {
    return MCPPromptName.allCases
      .sorted { $0.rawValue < $1.rawValue }
      .map { prompt in
        Prompt(
          name: prompt.rawValue,
          description: prompt.description,
          arguments: prompt.arguments
        )
      }
  }

  /// Resolves and executes a prompt by name using validated prompt arguments.
  func getPrompt(
    name: String,
    arguments: [String: Value]?
  ) throws -> GetPrompt.Result {
    guard let prompt = MCPPromptName(rawValue: name) else {
      throw MCPError.invalidParams("Unknown prompt name: \(name)")
    }

    let input: MCPPromptArguments

    do {
      input = try MCPPromptArgumentParser.parse(arguments)
    } catch let error as MCPPromptArgumentError {
      throw MCPError.invalidParams(error.localizedDescription)
    }

    let output: String

    switch prompt {
    case .sessionExport:
      output = try exportPrompt(input: input)
    case .sessionGraph:
      output = try graphPrompt(input: input)
    }

    let message: Prompt.Message = .user(.text(text: output))

    return GetPrompt.Result(description: nil, messages: [message])
  }

  private func exportPrompt(input: MCPPromptArguments) throws -> String {
    do {
      let sessionInput = try MCPInternalSupport.resolveSessionInput(
        scopes: scopes,
        selection: input.selection
      )

      return try MCPInternalSupport.exportOutput(
        scopes: scopes,
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides,
        targetPaths: input.targetPaths,
        referenceTags: input.referenceTags
      )
    } catch let error as ExportError {
      throw MCPError.invalidParams(MCPInternalSupport.formatExportError(error))
    }
  }

  private func graphPrompt(input: MCPPromptArguments) throws -> String {
    do {
      let sessionInput = try MCPInternalSupport.resolveSessionInput(
        scopes: scopes,
        selection: input.selection
      )

      return try MCPInternalSupport.graphOutput(
        scopes: scopes,
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides
      )
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(MCPInternalSupport.formatRegistryErrors(error.errors))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(MCPInternalSupport.formatResolutionErrors(error.errors))
    }
  }
}
