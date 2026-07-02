import Foundation

/// Built-in essential contracts injected into every resolved PersonaKit session.
enum SystemEssentials {
  static let personaActivationContractId = "persona-activation-contract"
  static let skillAuthorizationContractId = "skill-authorization-contract"

  static let injectedEssentialIds = [
    personaActivationContractId,
    skillAuthorizationContractId,
  ]

  static func expectedPath(for essentialId: String) -> String {
    PersonaKitPathSafety.expectedPath(
      baseRelativePath: "Packs/essentials",
      segment: essentialId,
      suffix: ".md"
    )
  }

  static func builtInContent(for essentialId: String) -> String? {
    switch essentialId {
    case personaActivationContractId:
      return """
        # Persona Activation Contract

        One active operating persona per lane; an assignment stays authoritative until explicitly replaced. Reassignment requires fresh grounding and prior assumptions must not carry forward. If authoritative grounding is unavailable, stop rather than blend or infer identity.
        """
    case skillAuthorizationContractId:
      return """
        # Skill Authorization Contract

        Only PersonaKit-declared skills are authorized; anything undeclared is unauthorized by default. Persona `allowedSkillIds` set the ceiling and `forbiddenSkillIds` hard-deny; a required-but-unauthorized skill stops execution. The resolved outcome is in `# Skill Contract`.
        """
    default:
      return nil
    }
  }

  static func sortEssentialIdsForResolvedOutput(_ ids: [String]) -> [String] {
    ids.sorted { lhs, rhs in
      let lhsRank = resolvedOutputRank(for: lhs)
      let rhsRank = resolvedOutputRank(for: rhs)

      if lhsRank != rhsRank {
        return lhsRank < rhsRank
      }

      return lhs < rhs
    }
  }

  static func sortResolvedEssentialsForResolvedOutput(
    _ essentials: [ResolvedEssential]
  ) -> [ResolvedEssential] {
    essentials.sorted { lhs, rhs in
      let lhsRank = resolvedOutputRank(for: lhs.id)
      let rhsRank = resolvedOutputRank(for: rhs.id)

      if lhsRank != rhsRank {
        return lhsRank < rhsRank
      }

      return lhs.id < rhs.id
    }
  }

  private static func resolvedOutputRank(for essentialId: String) -> Int {
    switch essentialId {
    case personaActivationContractId:
      return 0
    case skillAuthorizationContractId:
      return 1
    default:
      return 2
    }
  }
}

func activeRootURL(for scopes: ScopeSet) -> URL? {
  scopes.projectScopeURL ?? scopes.globalScopeURL
}

/// Public resolver for essential references, including PersonaKit built-in contracts.
public enum PersonaKitEssentialResolver {
  public static var builtInEssentialIds: [String] {
    SystemEssentials.injectedEssentialIds
  }

  public static func resolve(
    _ essentialId: String,
    scopes: ScopeSet,
    fileExists: (URL) -> Bool
  ) -> ResolvedEssential? {
    if SystemEssentials.injectedEssentialIds.contains(essentialId) {
      return resolveSystemEssential(
        essentialId,
        scopes: scopes,
        fileExists: fileExists
      )
    }

    guard
      let fileURL = resolveFileURL(
        essentialId,
        scopes: scopes,
        fileExists: fileExists
      )
    else {
      return nil
    }

    return ResolvedEssential(
      id: essentialId,
      url: fileURL,
      content: nil,
      source: .file
    )
  }

  public static func resolve(
    _ essentialId: String,
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> ResolvedEssential? {
    resolve(essentialId, scopes: scopes) { url in
      fileManager.fileExists(atPath: url.path)
    }
  }

  public static func expectedPath(for essentialId: String) -> String {
    SystemEssentials.expectedPath(for: essentialId)
  }

  public static func resolveFileURL(
    _ essentialId: String,
    scopes: ScopeSet,
    fileExists: (URL) -> Bool
  ) -> URL? {
    for root in scopes.resolutionOrder {
      let essentialsURL = root.appendingPathComponent("Packs/essentials", isDirectory: true)

      guard
        let fileURL = PersonaKitPathSafety.containedFileURL(
          root: root,
          baseRelativePath: "Packs/essentials",
          segment: essentialId,
          suffix: ".md"
        )
      else {
        return nil
      }

      if fileExists(fileURL), PersonaKitPathSafety.canonicalContains(fileURL, in: essentialsURL) {
        return fileURL.standardizedFileURL
      }
    }

    return nil
  }

  public static func resolveFileURL(
    _ essentialId: String,
    scopes: ScopeSet,
    fileManager: FileManager
  ) -> URL? {
    resolveFileURL(essentialId, scopes: scopes) { url in
      fileManager.fileExists(atPath: url.path)
    }
  }

  private static func resolveSystemEssential(
    _ essentialId: String,
    scopes: ScopeSet,
    fileExists: (URL) -> Bool
  ) -> ResolvedEssential? {
    guard let rootURL = activeRootURL(for: scopes) else {
      return nil
    }

    guard
      let fileURL = PersonaKitPathSafety.containedFileURL(
        root: rootURL,
        baseRelativePath: "Packs/essentials",
        segment: essentialId,
        suffix: ".md"
      )
    else {
      return nil
    }

    let essentialsURL = rootURL.appendingPathComponent("Packs/essentials", isDirectory: true)

    if fileExists(fileURL), PersonaKitPathSafety.canonicalContains(fileURL, in: essentialsURL) {
      return ResolvedEssential(
        id: essentialId,
        url: fileURL.standardizedFileURL,
        content: nil,
        source: .file
      )
    }

    guard let content = SystemEssentials.builtInContent(for: essentialId) else {
      return nil
    }

    return ResolvedEssential(
      id: essentialId,
      url: fileURL,
      content: content,
      source: .systemBuiltIn
    )
  }
}

func resolveReferencedEssential(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> ResolvedEssential? {
  PersonaKitEssentialResolver.resolve(
    essentialId,
    scopes: scopes,
    fileManager: fileManager
  )
}
