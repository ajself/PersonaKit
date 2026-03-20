import ContextCore
import Foundation
import MCP

func mcpParameterConstraintSummary(_ constraint: IntentTemplate.ParameterConstraint) -> String {
  "\(constraint.kind):" + constraint.parameterNames.joined(separator: ",")
}

func mcpDirectiveExplainWorkstreamData(
  _ workstream: Directive.Workstream
) -> DirectiveExplainWorkstreamData {
  DirectiveExplainWorkstreamData(
    id: workstream.id,
    phase: workstream.phase,
    entrySessionId: workstream.entrySessionId,
    requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
    nodeCount: workstream.nodes.count,
    edgeCount: workstream.edges.count
  )
}

func mcpSessionTraceWorkstream(
  _ workstream: Directive.Workstream,
  activeSessionId: String
) -> SessionTraceWorkstream {
  let currentNode = workstream.node(forSessionId: activeSessionId)

  return SessionTraceWorkstream(
    id: workstream.id,
    phase: workstream.phase,
    currentSessionId: currentNode?.sessionId,
    entrySessionId: workstream.entrySessionId,
    requiredCloseoutSessionId: workstream.requiredCloseoutSessionId,
    nextSessionIds: workstream.nextSessionIds(fromSessionId: activeSessionId),
    nodes: workstream.orderedNodes.map {
      SessionTraceWorkstreamNode(
        sessionId: $0.sessionId,
        phase: $0.phase
      )
    },
    edges: workstream.orderedEdges.map {
      SessionTraceWorkstreamEdge(
        fromSessionId: $0.fromSessionId,
        toSessionId: $0.toSessionId,
        kind: $0.kind
      )
    }
  )
}

func mcpEncodeToolJSON<T: Encodable>(_ payload: T) throws -> String {
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

func mcpFormatExportError(_ error: ExportError) -> String {
  switch error {
  case .validationFailed(let result):
    var lines: [String] = [result.summary]
    lines.append(contentsOf: result.errors.map { $0.lineDescription() })
    return lines.joined(separator: "\n")
  case .resolutionFailed(let resolutionError):
    return mcpFormatResolutionErrors(resolutionError.errors)
  case .readFailed(let message):
    return "Error: \(message)"
  }
}

func mcpFormatResolutionErrors(_ errors: [ResolverError]) -> String {
  return errors.map { mcpFormatResolutionError($0) }.joined(separator: "\n")
}

func mcpFormatResolutionError(_ error: ResolverError) -> String {
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

func mcpFormatRegistryErrors(_ errors: [RegistryError]) -> String {
  return errors.map { mcpFormatRegistryError($0) }.joined(separator: "\n")
}

func mcpFormatRegistryError(_ error: RegistryError) -> String {
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

func mcpWithRecoveryHint(_ message: String, hint: String) -> String {
  return "\(message)\nRecovery: \(hint)"
}

func mcpMissingEntityMessage(entityType: MCPEntityType, id: String) -> String {
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
  return mcpWithRecoveryHint(
    "\(entityType.rawValue) not found: \(id)",
    hint: "Read personakit://catalog/\(catalogType) to list valid ids, then retry."
  )
}

func mcpUniqueSorted(_ ids: [String]) -> [String] {
  return Set(ids).sorted()
}

func mcpResolveEssentialURL(id: String, scopes: ScopeSet, fileManager: FileManager) -> URL? {
  let relativePath = "Packs/essentials/\(id).md"
  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(relativePath)
    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }
  return nil
}

func mcpLineCount(_ text: String) -> Int {
  if text.isEmpty {
    return 0
  }
  return text.split(separator: "\n", omittingEmptySubsequences: false).count
}

func mcpListSessions(scopes: ScopeSet, fileManager: FileManager) throws -> [SessionFile] {
  do {
    return try SessionFileLoader.list(scopes: scopes, fileManager: fileManager)
  } catch {
    throw MCPError.internalError("Failed to load session files.")
  }
}

func mcpTokenSet(_ text: String) -> [String] {
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

  return mcpUniqueSorted(parts)
}

func mcpMatchedTerms(goalTerms: [String], text: String) -> [String] {
  let haystack = text.lowercased()
  return goalTerms.filter { haystack.contains($0) }
}
