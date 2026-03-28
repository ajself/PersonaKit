import ContextCore
import Foundation
import MCP

enum MCPInternalSupport {
  static func parameterConstraintSummary(_ constraint: IntentTemplate.ParameterConstraint) -> String {
    "\(constraint.kind):" + constraint.parameterNames.joined(separator: ",")
  }

  static func directiveExplainWorkstreamData(
    _ workstream: Directive.Workstream
  ) -> MCPToolPayloads.DirectiveExplainWorkstreamData {
    MCPToolPayloads.DirectiveExplainWorkstreamData(
      id: workstream.id,
      phase: workstream.phase,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nodeCount: workstream.nodes.count,
      edgeCount: workstream.edges.count
    )
  }

  static func sessionTraceWorkstream(
    _ workstream: Directive.Workstream,
    activeSessionId: String
  ) -> MCPToolPayloads.SessionTraceWorkstream {
    let currentNode = workstream.node(forSessionId: activeSessionId)

    return MCPToolPayloads.SessionTraceWorkstream(
      id: workstream.id,
      phase: workstream.phase,
      currentSessionId: currentNode?.sessionId,
      entrySessionId: workstream.entrySessionId,
      requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
      nextSessionIds: workstream.nextSessionIds(fromSessionId: activeSessionId),
      nodes: workstream.orderedNodes.map {
        MCPToolPayloads.SessionTraceWorkstreamNode(
          sessionId: $0.sessionId,
          phase: $0.phase
        )
      },
      edges: workstream.orderedEdges.map {
        MCPToolPayloads.SessionTraceWorkstreamEdge(
          fromSessionId: $0.fromSessionId,
          toSessionId: $0.toSessionId,
          kind: $0.kind
        )
      }
    )
  }

  static func encodeToolJSON<T: Encodable>(_ payload: T) throws -> String {
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

  static func exportOutput(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String],
    targetPaths: [String] = [],
    requestFlags: [String] = []
  ) throws -> String {
    let output = try SessionExporter.export(
      scopes: scopes,
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      targetPaths: targetPaths,
      requestFlags: requestFlags
    )
    return output + "\n"
  }

  static func graphOutput(
    scopes: ScopeSet,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> String {
    let registry = try Registry.load(scopes: scopes)
    let definition = SessionDefinition(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides.isEmpty ? nil : kitOverrides
    )
    let resolved = try Resolver.resolve(
      definition: definition,
      registry: registry,
      scopes: scopes
    )
    let output = GraphPrinter.render(
      resolvedSession: resolved,
      kitOverrides: kitOverrides
    )
    return output + "\n"
  }

  static func formatExportError(_ error: ExportError) -> String {
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

  static func formatResolutionErrors(_ errors: [ResolverError]) -> String {
    return errors.map { formatResolutionError($0) }.joined(separator: "\n")
  }

  static func formatResolutionError(_ error: ResolverError) -> String {
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
    } else if case .missingReferenceId(_, _, _, let missingId) = error {
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

  static func formatRegistryErrors(_ errors: [RegistryError]) -> String {
    return errors.map { formatRegistryError($0) }.joined(separator: "\n")
  }

  static func formatRegistryError(_ error: RegistryError) -> String {
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

  static func withRecoveryHint(_ message: String, hint: String) -> String {
    return "\(message)\nRecovery: \(hint)"
  }

  static func missingEntityMessage(entityType: MCPEntityType, id: String) -> String {
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
    case .reference:
      return withRecoveryHint(
        "reference not found: \(id)",
        hint:
          "Use personakit_trace_session or personakit_resolve_references for the active workflow to discover available reference ids, then retry."
      )
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

  static func uniqueSorted(_ ids: [String]) -> [String] {
    return Set(ids).sorted()
  }

  static func resolveEssentialURL(id: String, scopes: ScopeSet, fileManager: FileManager) -> URL? {
    let relativePath = "Packs/essentials/\(id).md"
    for root in scopes.resolutionOrder {
      let fileURL = root.appendingPathComponent(relativePath)
      if fileManager.fileExists(atPath: fileURL.path) {
        return fileURL
      }
    }
    return nil
  }

  static func lineCount(_ text: String) -> Int {
    if text.isEmpty {
      return 0
    }
    return text.split(separator: "\n", omittingEmptySubsequences: false).count
  }

  static func listSessions(scopes: ScopeSet, fileManager: FileManager) throws -> [SessionFile] {
    do {
      return try SessionFileLoader.list(scopes: scopes, fileManager: fileManager)
    } catch {
      throw MCPError.internalError("Failed to load session files.")
    }
  }

  static func tokenSet(_ text: String) -> [String] {
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

  static func matchedTerms(goalTerms: [String], text: String) -> [String] {
    let haystack = text.lowercased()
    return goalTerms.filter { haystack.contains($0) }
  }
}
