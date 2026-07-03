import Foundation

/// Error produced while resolving or expanding grounding-skill bodies.
public enum GroundingSkillResolutionError: Error, Equatable {
  case missingBody(id: String, expectedPath: String)
  case readFailed(id: String)

  public var message: String {
    switch self {
    case .missingBody(_, let expectedPath):
      return "Missing grounding-skill body at \(expectedPath)."
    case .readFailed(let id):
      return "Failed to read grounding-skill body: \(id)."
    }
  }
}

/// Fully loaded grounding-skill body for export-time expansion.
public struct ExpandedGroundingSkillDocument: Equatable, Sendable {
  public let id: String
  public let title: String
  public let content: String
  public let match: ResolvedGroundingSkillMatch

  public init(
    id: String,
    title: String,
    content: String,
    match: ResolvedGroundingSkillMatch
  ) {
    self.id = id
    self.title = title
    self.content = content
    self.match = match
  }
}

/// Deterministic grounding-skill trigger evaluation shared by export, CLI, and MCP surfaces.
public enum GroundingSkillSupport {
  public static func triggerSummary(for groundingSkill: ResolvedGroundingSkill) -> String {
    let summaries = groundingSkill.triggerRules.map { rule in
      triggerSummary(for: rule)
    }
    return summaries.joined(separator: " | ")
  }

  public static func triggerSummary(for rule: SkillTriggerRule) -> String {
    var parts: [String] = []

    let pathGlobs = uniqueSorted(rule.pathGlobs ?? [])
    if !pathGlobs.isEmpty {
      parts.append("paths=" + pathGlobs.joined(separator: ", "))
    }

    let skillTags = uniqueSorted(rule.skillTags ?? [])
    if !skillTags.isEmpty {
      parts.append("skillTags=" + skillTags.joined(separator: ", "))
    }

    return parts.joined(separator: " + ")
  }

  public static func resolveMatches(
    availableGroundingSkills: [ResolvedGroundingSkill],
    input: SkillTriggerSelectionInput
  ) -> [ResolvedGroundingSkillMatch] {
    guard !input.isEmpty else {
      return []
    }

    return availableGroundingSkills.compactMap { groundingSkill in
      let matchedRules = groundingSkill.triggerRules.enumerated().compactMap { index, rule in
        matchRule(
          rule,
          ruleIndex: index,
          input: input
        )
      }

      guard !matchedRules.isEmpty else {
        return nil
      }

      return ResolvedGroundingSkillMatch(
        id: groundingSkill.id,
        name: groundingSkill.name,
        description: groundingSkill.description,
        sources: groundingSkill.sources,
        matchedRules: matchedRules
      )
    }
  }

  public static func loadExpandedDocuments(
    matches: [ResolvedGroundingSkillMatch],
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [ExpandedGroundingSkillDocument] {
    return try matches.map { match in
      let expectedPath = groundingSkillBodyRelativePath(id: match.id)
      guard let bodyURL = resolveGroundingSkillBodyURL(id: match.id, scopes: scopes, fileManager: fileManager)
      else {
        throw GroundingSkillResolutionError.missingBody(id: match.id, expectedPath: expectedPath)
      }

      let text: String

      do {
        text = try String(contentsOf: bodyURL, encoding: .utf8)
      } catch {
        throw GroundingSkillResolutionError.readFailed(id: match.id)
      }

      var normalizedText = text
      if !normalizedText.hasSuffix("\n") {
        normalizedText.append("\n")
      }

      return ExpandedGroundingSkillDocument(
        id: match.id,
        title: match.name,
        content: normalizedText,
        match: match
      )
    }
  }

  public static func resolveGroundingSkillBodyURL(
    id: String,
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) -> URL? {
    for root in scopes.resolutionOrder {
      if let fileURL = resolveGroundingSkillBodyURL(id: id, root: root, fileManager: fileManager) {
        return fileURL
      }
    }

    return nil
  }

  public static func groundingSkillBodyRelativePath(id: String) -> String {
    PersonaKitPathSafety.expectedPath(
      baseRelativePath: "Packs/skills",
      segment: id,
      suffix: ".md"
    )
  }

  static func resolveGroundingSkillBodyURL(
    id: String,
    root: URL,
    fileManager: FileManager = .default
  ) -> URL? {
    let skillsURL = root.appendingPathComponent("Packs/skills", isDirectory: true)

    guard
      let fileURL = PersonaKitPathSafety.containedFileURL(
        root: root,
        baseRelativePath: "Packs/skills",
        segment: id,
        suffix: ".md"
      )
    else {
      return nil
    }

    guard fileManager.fileExists(atPath: fileURL.path) else {
      return nil
    }

    guard PersonaKitPathSafety.canonicalContains(fileURL, in: skillsURL) else {
      return nil
    }

    return fileURL.standardizedFileURL
  }

  private static func matchRule(
    _ rule: SkillTriggerRule,
    ruleIndex: Int,
    input: SkillTriggerSelectionInput
  ) -> ResolvedGroundingSkillMatchRule? {
    let pathGlobs = uniqueSorted(rule.pathGlobs ?? [])
    let skillTags = uniqueSorted((rule.skillTags ?? []).map { $0.lowercased() })

    var matchedPathGlobs: [String] = []
    var matchedPaths: [String] = []
    var matchedSkillTags: [String] = []

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

    if !skillTags.isEmpty {
      matchedSkillTags = skillTags.filter { input.skillTags.contains($0) }
      if matchedSkillTags.isEmpty {
        return nil
      }
    }

    return ResolvedGroundingSkillMatchRule(
      ruleIndex: ruleIndex,
      matchedPathGlobs: matchedPathGlobs,
      matchedPaths: uniqueSorted(matchedPaths),
      matchedSkillTags: matchedSkillTags
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
