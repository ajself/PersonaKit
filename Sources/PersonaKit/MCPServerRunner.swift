import Dispatch
import Foundation
import MCP

protocol MCPServerRunning {
    func run(version: String) throws
}

struct MCPServerRunner: MCPServerRunning {
    func run(version: String) throws {
        Task {
            do {
                try await runServer(version: version)
            } catch {
                var stderrStream = StandardError()
                stderrStream.write("Error: MCP server failed to start: \(error.localizedDescription)\n")
                exit(1)
            }
        }
        dispatchMain()
    }

    private func runServer(version: String) async throws {
        guard let scopes = ScopeRootResolver().locate(), !scopes.isEmpty else {
            throw MCPServerRunnerError.missingScopes
        }

        let registry: Registry
        do {
            registry = try Registry.load(scopes: scopes)
        } catch let error as RegistryLoadError {
            throw MCPServerRunnerError.registryLoadFailed(error.errors)
        }

        let resourceService = MCPResourceService(registry: registry, scopes: scopes)

        let server = Server(
            name: "PersonaKit",
            version: version,
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false)
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
            return "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
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
