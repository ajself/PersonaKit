import ContextCore
import Dispatch
import Foundation
import MCP

/// Runner abstraction for starting the PersonaKit MCP server process.
public protocol MCPServerRunning: Sendable {
  /// Starts the MCP server using the provided semantic version string.
  func run(version: String, scopes: ScopeSet) throws
}

/// Default MCP server bootstrap implementation for CLI `personakit mcp`.
public struct MCPServerRunner: MCPServerRunning {
  public init() {}

  /// Starts the async MCP server loop and blocks the process main thread.
  public func run(version: String, scopes: ScopeSet) throws {
    Task {
      do {
        try await runServer(version: version, scopes: scopes)
      } catch {
        var stderrStream = MCPStandardError()
        stderrStream.write("Error: MCP server failed to start: \(error.localizedDescription)\n")
        exit(1)
      }
    }
    dispatchMain()
  }

  private func runServer(version: String, scopes: ScopeSet) async throws {
    guard !scopes.isEmpty else {
      throw MCPServerRunnerError.missingScopes
    }

    let registry: Registry
    do {
      registry = try Registry.load(scopes: scopes)
    } catch let error as RegistryLoadError {
      throw MCPServerRunnerError.registryLoadFailed(error.errors)
    }

    let resourceService = MCPResourceService(registry: registry, scopes: scopes)
    let promptService = MCPPromptService(scopes: scopes)
    let toolService = MCPToolService(scopes: scopes)

    let server = Server(
      name: "PersonaKit",
      version: version,
      capabilities: .init(
        prompts: .init(listChanged: false),
        resources: .init(subscribe: false, listChanged: false),
        tools: .init(listChanged: false)
      )
    )

    await server.withMethodHandler(ListResources.self) { _ in
      let resources = try resourceService.listResources()
      return ListResources.Result(resources: resources, nextCursor: nil)
    }

    await server.withMethodHandler(ReadResource.self) { params in
      let content = try resourceService.readResource(uri: params.uri)
      return ReadResource.Result(contents: [content])
    }

    await server.withMethodHandler(ListPrompts.self) { _ in
      let prompts = promptService.listPrompts()
      return ListPrompts.Result(prompts: prompts, nextCursor: nil)
    }

    await server.withMethodHandler(GetPrompt.self) { params in
      let promptArguments = params.arguments?.mapValues { Value.string($0) }
      return try promptService.getPrompt(
        name: params.name,
        arguments: promptArguments
      )
    }

    await server.withMethodHandler(ListTools.self) { _ in
      let tools = toolService.listTools()
      return ListTools.Result(tools: tools, nextCursor: nil)
    }

    await server.withMethodHandler(CallTool.self) { params in
      return try toolService.callTool(
        name: params.name,
        arguments: params.arguments
      )
    }

    let transport = StdioTransport()
    try await server.start(transport: transport)
    let sleepNanoseconds = UInt64(60 * 60 * 24 * 365 * 100) * 1_000_000_000
    try await Task.sleep(nanoseconds: sleepNanoseconds)
  }
}

private enum MCPServerRunnerError: LocalizedError {
  case missingScopes
  case registryLoadFailed([RegistryError])

  var errorDescription: String? {
    switch self {
    case .missingScopes:
      return
        "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
    case .registryLoadFailed(let errors):
      return errors.map { formatRegistryError($0) }.joined(separator: "\n")
    }
  }
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
  return parts.joined(separator: " ")
}

/// `stderr` text stream used by MCP server startup failures.
private struct MCPStandardError: TextOutputStream {
  mutating func write(_ string: String) {
    guard let data = string.data(using: .utf8) else {
      return
    }

    FileHandle.standardError.write(data)
  }
}
