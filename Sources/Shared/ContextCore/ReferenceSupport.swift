import Foundation

/// Error produced while resolving or expanding reference bodies.
public enum ReferenceResolutionError: Error, Equatable {
  case missingBody(id: String, expectedPath: String)
  case readFailed(id: String)

  public var message: String {
    switch self {
    case .missingBody(_, let expectedPath):
      return "Missing reference body at \(expectedPath)."
    case .readFailed(let id):
      return "Failed to read reference body: \(id)."
    }
  }
}

/// Fully loaded reference body for export-time expansion.
public struct ExpandedReferenceDocument: Equatable, Sendable {
  public let id: String
  public let title: String
  public let content: String
  public let match: ResolvedReferenceMatch

  public init(
    id: String,
    title: String,
    content: String,
    match: ResolvedReferenceMatch
  ) {
    self.id = id
    self.title = title
    self.content = content
    self.match = match
  }
}

/// Deterministic reference evaluation helpers shared by export, CLI, and MCP surfaces.
public enum ReferenceSupport {
  public static func triggerSummary(for reference: ResolvedReference) -> String {
    let summaries = reference.triggerRules.enumerated().map { _, rule in
      triggerSummary(for: rule)
    }
    return summaries.joined(separator: " | ")
  }

  public static func triggerSummary(for rule: ReferenceTriggerRule) -> String {
    var parts: [String] = []

    let pathGlobs = uniqueSorted(rule.pathGlobs ?? [])
    if !pathGlobs.isEmpty {
      parts.append("paths=" + pathGlobs.joined(separator: ", "))
    }

    let requestFlags = uniqueSorted(rule.requestFlags ?? [])
    if !requestFlags.isEmpty {
      parts.append("flags=" + requestFlags.joined(separator: ", "))
    }

    return parts.joined(separator: " + ")
  }

  public static func resolveMatches(
    availableReferences: [ResolvedReference],
    input: ReferenceSelectionInput
  ) -> [ResolvedReferenceMatch] {
    guard !input.isEmpty else {
      return []
    }

    return availableReferences.compactMap { reference in
      let matchedRules = reference.triggerRules.enumerated().compactMap { index, rule in
        matchRule(
          rule,
          ruleIndex: index,
          input: input
        )
      }

      guard !matchedRules.isEmpty else {
        return nil
      }

      return ResolvedReferenceMatch(
        id: reference.id,
        name: reference.name,
        summary: reference.summary,
        sources: reference.sources,
        matchedRules: matchedRules
      )
    }
  }

  public static func loadExpandedDocuments(
    matches: [ResolvedReferenceMatch],
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [ExpandedReferenceDocument] {
    return try matches.map { match in
      let expectedPath = referenceBodyRelativePath(id: match.id)
      guard let bodyURL = resolveReferenceBodyURL(id: match.id, scopes: scopes, fileManager: fileManager)
      else {
        throw ReferenceResolutionError.missingBody(id: match.id, expectedPath: expectedPath)
      }

      let text: String

      do {
        text = try String(contentsOf: bodyURL, encoding: .utf8)
      } catch {
        throw ReferenceResolutionError.readFailed(id: match.id)
      }

      var normalizedText = text
      if !normalizedText.hasSuffix("\n") {
        normalizedText.append("\n")
      }

      return ExpandedReferenceDocument(
        id: match.id,
        title: match.name,
        content: normalizedText,
        match: match
      )
    }
  }

  public static func resolveReferenceBodyURL(
    id: String,
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) -> URL? {
    let relativePath = referenceBodyRelativePath(id: id)
    for root in scopes.resolutionOrder {
      let fileURL = root.appendingPathComponent(relativePath)
      if fileManager.fileExists(atPath: fileURL.path) {
        return fileURL
      }
    }
    return nil
  }

  public static func referenceBodyRelativePath(id: String) -> String {
    "Packs/references/\(id).md"
  }

  private static func matchRule(
    _ rule: ReferenceTriggerRule,
    ruleIndex: Int,
    input: ReferenceSelectionInput
  ) -> ResolvedReferenceMatchRule? {
    let pathGlobs = uniqueSorted(rule.pathGlobs ?? [])
    let requestFlags = uniqueSorted((rule.requestFlags ?? []).map { $0.lowercased() })

    var matchedPathGlobs: [String] = []
    var matchedPaths: [String] = []
    var matchedRequestFlags: [String] = []

    if !pathGlobs.isEmpty {
      for pathGlob in pathGlobs {
        let paths = input.targetPaths.filter { path in
          pathMatchesGlob(path, glob: pathGlob)
        }
        if !paths.isEmpty {
          matchedPathGlobs.append(pathGlob)
          matchedPaths.append(contentsOf: paths)
        }
      }

      if matchedPathGlobs.isEmpty {
        return nil
      }
    }

    if !requestFlags.isEmpty {
      matchedRequestFlags = requestFlags.filter { input.requestFlags.contains($0) }
      if matchedRequestFlags.isEmpty {
        return nil
      }
    }

    return ResolvedReferenceMatchRule(
      ruleIndex: ruleIndex,
      matchedPathGlobs: matchedPathGlobs,
      matchedPaths: uniqueSorted(matchedPaths),
      matchedRequestFlags: matchedRequestFlags
    )
  }
}

private func pathMatchesGlob(_ path: String, glob: String) -> Bool {
  let pattern = regexPattern(forGlob: glob)
  guard let regularExpression = try? NSRegularExpression(pattern: pattern) else {
    return false
  }

  let normalizedPath = path.replacingOccurrences(of: "\\", with: "/")
  let range = NSRange(normalizedPath.startIndex..<normalizedPath.endIndex, in: normalizedPath)
  return regularExpression.firstMatch(in: normalizedPath, options: [], range: range) != nil
}

private func regexPattern(forGlob glob: String) -> String {
  let normalizedGlob = glob.replacingOccurrences(of: "\\", with: "/")
  var pattern = "^"
  var index = normalizedGlob.startIndex

  while index < normalizedGlob.endIndex {
    if normalizedGlob[index...].hasPrefix("**/") {
      pattern += "(?:.*/)?"
      index = normalizedGlob.index(index, offsetBy: 3)
      continue
    }

    if normalizedGlob[index...].hasPrefix("**") {
      pattern += ".*"
      index = normalizedGlob.index(index, offsetBy: 2)
      continue
    }

    let character = normalizedGlob[index]
    switch character {
    case "*":
      pattern += "[^/]*"
    case "?":
      pattern += "[^/]"
    case ".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
      pattern += "\\\(character)"
    default:
      pattern.append(character)
    }

    index = normalizedGlob.index(after: index)
  }

  pattern += "$"
  return pattern
}

private func uniqueSorted(_ values: [String]) -> [String] {
  Set(values).sorted()
}
