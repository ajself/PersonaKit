import ContextCore
import MCP

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
        MCPInternalSupport.withRecoveryHint(
          "Unknown tool name: \(name)",
          hint: "Call list_tools and retry using one of the advertised tool names."
        )
      )
    }

    switch tool {
    case .bestGuidance:
      let output = try bestGuidanceTool(arguments: arguments)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .validate:
      let output = try validateTool(arguments: arguments)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .contract:
      let input = try parseContractArguments(arguments)
      let output = try contractTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .export:
      let input = try parseSessionArguments(arguments)
      let output = try exportTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .graph:
      let input = try parseSessionArguments(arguments)
      let output = try graphTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .resolveReferences:
      let input = try parseSessionArguments(arguments)
      let output = try resolveReferencesTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .explainEntity:
      let input = try parseEntityArguments(arguments)
      let output = try explainEntityTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .compareEntities:
      let input = try parseCompareArguments(arguments)
      let output = try compareEntitiesTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .recommendSession:
      let input = try parseRecommendArguments(arguments)
      let output = try recommendSessionTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .resolveSessionRef:
      let input = try parseResolveSessionArguments(arguments)
      let output = try resolveSessionRefTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    case .traceSession:
      let input = try parseTraceArguments(arguments)
      let output = try traceSessionTool(input: input)
      return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    }
  }

  private func bestGuidanceTool(arguments: [String: Value]?) throws -> String {
    guard arguments?.isEmpty ?? true else {
      throw MCPError.invalidParams("personakit_best_guidance does not accept arguments.")
    }

    return try BestGuidanceSupport.encodeJSON(BestGuidanceSupport.build(scopes: scopes))
  }

  private func parseSessionArguments(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    do {
      return try MCPToolArgumentParser.parseSession(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint: "Provide personaId and directiveId as non-empty strings, plus optional kits."
        )
      )
    }
  }

  private func parseContractArguments(_ arguments: [String: Value]?) throws -> MCPContractArguments {
    do {
      return try MCPToolArgumentParser.parseContract(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint:
            "Provide sessionId alone, or personaId with optional directiveId, plus optional requestedSkillIds."
        )
      )
    }
  }

  private func parseEntityArguments(_ arguments: [String: Value]?) throws -> MCPEntityArguments {
    do {
      return try MCPToolArgumentParser.parseEntity(arguments)
    } catch let error as MCPToolArgumentError {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
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
        MCPInternalSupport.withRecoveryHint(
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
        MCPInternalSupport.withRecoveryHint(
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
        MCPInternalSupport.withRecoveryHint(
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
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint: "Provide sessionRef as a non-empty session id or session-file path."
        )
      )
    }
  }

  func loadRegistry() throws -> Registry {
    do {
      return try Registry.load(scopes: scopes)
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(MCPInternalSupport.formatRegistryErrors(error.errors))
    }
  }

  func loadSession(id: String) throws -> SessionFile {
    do {
      return try SessionFileLoader.load(scopes: scopes, sessionId: id)
    } catch let error as SessionFileError {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint: "Read personakit://catalog/sessions to list valid ids, then retry with one session id."
        )
      )
    }
  }
}
