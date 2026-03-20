import Foundation

enum ValidatorWorkstreamValidator {
  static func validate(
    _ workstream: Directive.Workstream,
    directiveId: String,
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> [ValidationError] {
    var errors: [ValidationError] = []

    let phases = workstream.nodes.map(\.phase)
    let sessionIds = workstream.nodes.map(\.sessionId)
    let edgeTriplets = workstream.edges.map { "\($0.fromSessionId)|\($0.toSessionId)|\($0.kind)" }

    if let duplicatePhase = duplicateValue(in: phases) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.nodes.phase",
          missingId: duplicatePhase,
          expectedPath: nil,
          message: "Duplicate workstream node phase \"\(duplicatePhase)\"."
        )
      )
    }

    if let duplicateSessionId = duplicateValue(in: sessionIds) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.nodes.sessionId",
          missingId: duplicateSessionId,
          expectedPath: nil,
          message: "Duplicate workstream node session id \"\(duplicateSessionId)\"."
        )
      )
    }

    if let duplicateEdge = duplicateValue(in: edgeTriplets) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.edges",
          missingId: duplicateEdge,
          expectedPath: nil,
          message: "Duplicate workstream edge \"\(duplicateEdge)\"."
        )
      )
    }

    let phaseMatches = workstream.nodes.filter { $0.phase == workstream.phase }
    if phaseMatches.count != 1 {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.phase",
          missingId: workstream.phase,
          expectedPath: nil,
          message: "Workstream phase \"\(workstream.phase)\" must match exactly one node phase."
        )
      )
    }

    let declaredSessionIds = Set(sessionIds)

    if !declaredSessionIds.contains(workstream.entrySessionId) {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.entrySessionId",
          missingId: workstream.entrySessionId,
          expectedPath: "Sessions/\(workstream.entrySessionId).session.json",
          message: "Workstream entry session id \"\(workstream.entrySessionId)\" must be declared in workstream nodes."
        )
      )
    }

    if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId,
      !declaredSessionIds.contains(requiredCloseoutSessionId)
    {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.requiredCloseoutSessionId",
          missingId: requiredCloseoutSessionId,
          expectedPath: "Sessions/\(requiredCloseoutSessionId).session.json",
          message: "Required closeout session id \"\(requiredCloseoutSessionId)\" must be declared in workstream nodes."
        )
      )
    }

    for sessionId in declaredSessionIds.sorted() {
      do {
        _ = try SessionFileLoader.load(
          scopes: scopes,
          sessionId: sessionId,
          fileManager: fileManager
        )
      } catch let error as SessionFileError {
        let message: String

        switch error {
        case .notFound:
          message = "Missing session file for workstream node id \"\(sessionId)\"."
        case .idMismatch:
          message = "Workstream node session id \"\(sessionId)\" failed to resolve: \(error.localizedDescription)"
        case .decodeFailed:
          message = "Workstream node session id \"\(sessionId)\" failed to decode."
        case .invalidSessionId, .invalidSessionPath:
          message = "Workstream node session id \"\(sessionId)\" failed to resolve."
        }

        errors.append(
          ValidationError(
            entityType: .directive,
            entityId: directiveId,
            field: "workstream.nodes.sessionId",
            missingId: sessionId,
            expectedPath: "Sessions/\(sessionId).session.json",
            message: message
          )
        )
      } catch {
        errors.append(
          ValidationError(
            entityType: .directive,
            entityId: directiveId,
            field: "workstream.nodes.sessionId",
            missingId: sessionId,
            expectedPath: "Sessions/\(sessionId).session.json",
            message: "Workstream node session id \"\(sessionId)\" failed to resolve."
          )
        )
      }
    }

    for edge in workstream.edges {
      if !declaredSessionIds.contains(edge.fromSessionId) {
        errors.append(
          ValidationError(
            entityType: .directive,
            entityId: directiveId,
            field: "workstream.edges.fromSessionId",
            missingId: edge.fromSessionId,
            expectedPath: "Sessions/\(edge.fromSessionId).session.json",
            message: "Workstream edge source session id \"\(edge.fromSessionId)\" must be declared in workstream nodes."
          )
        )
      }

      if !declaredSessionIds.contains(edge.toSessionId) {
        errors.append(
          ValidationError(
            entityType: .directive,
            entityId: directiveId,
            field: "workstream.edges.toSessionId",
            missingId: edge.toSessionId,
            expectedPath: "Sessions/\(edge.toSessionId).session.json",
            message: "Workstream edge target session id \"\(edge.toSessionId)\" must be declared in workstream nodes."
          )
        )
      }
    }

    if let requiredCloseoutSessionId = workstream.requiredCloseoutSessionId,
      declaredSessionIds.contains(workstream.entrySessionId),
      declaredSessionIds.contains(requiredCloseoutSessionId),
      !isReachable(
        from: workstream.entrySessionId,
        to: requiredCloseoutSessionId,
        edges: workstream.edges
      )
    {
      errors.append(
        ValidationError(
          entityType: .directive,
          entityId: directiveId,
          field: "workstream.requiredCloseoutSessionId",
          missingId: requiredCloseoutSessionId,
          expectedPath: "Sessions/\(requiredCloseoutSessionId).session.json",
          message:
            "Required closeout session id \"\(requiredCloseoutSessionId)\" is not reachable from entry session id \"\(workstream.entrySessionId)\"."
        )
      )
    }

    return errors
  }
}

private func duplicateValue(in values: [String]) -> String? {
  var seen: Set<String> = []

  for value in values {
    if seen.contains(value) {
      return value
    }
    seen.insert(value)
  }

  return nil
}

private func isReachable(
  from start: String,
  to target: String,
  edges: [Directive.Workstream.Edge]
) -> Bool {
  if start == target {
    return true
  }

  var queue = [start]
  var visited: Set<String> = [start]
  let adjacency = Dictionary(grouping: edges, by: \.fromSessionId)

  while !queue.isEmpty {
    let current = queue.removeFirst()

    for edge in adjacency[current] ?? [] {
      if edge.toSessionId == target {
        return true
      }

      if !visited.contains(edge.toSessionId) {
        visited.insert(edge.toSessionId)
        queue.append(edge.toSessionId)
      }
    }
  }

  return false
}
