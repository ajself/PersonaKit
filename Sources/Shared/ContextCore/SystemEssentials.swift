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
    "Packs/essentials/\(essentialId).md"
  }

  static func builtInContent(for essentialId: String) -> String? {
    switch essentialId {
    case personaActivationContractId:
      return """
        # Persona Activation Contract

        Use this essential as the universal runtime contract for persona assignment and reassignment.

        ## Core Rule

        PersonaKit treats persona assignment as an operating contract, not a tone preset.

        ## Runtime Rules

        1. One active persona per agent at a time.
        2. A persona assignment remains authoritative until explicitly replaced.
        3. Persona reassignment requires fresh grounding on persona, directive, kits, and essentials.
        4. Prior persona assumptions must not silently carry forward after reassignment.
        5. Orchestrator identity should stay stable during coordination.
        6. Each delegated lane must name one authoritative operating persona.
        7. Optional review personas may be recorded separately, but they are not the lane's execution identity.
        8. If authoritative grounding is unavailable, execution stops instead of degrading into inferred or blended identity.

        ## Reliable Multi-Persona Patterns

        Use one of these patterns when more than one persona is involved:

        1. Separate agents with distinct persona assignments.
        2. Explicitly labeled review turns that preserve one active operating persona.
        3. Durable handoff artifacts that record which persona owns execution and which personas contributed review input.

        ## Unreliable Pattern To Avoid

        Do not treat one agent as multiple active personas at the same time during execution.

        That pattern softens role boundaries, obscures stop points, and makes it hard to audit who supplied which judgment.
        """
    case skillAuthorizationContractId:
      return """
        # Skill Authorization Contract

        Use this essential as the universal runtime contract for skill selection after PersonaKit grounding.

        ## Core Rule

        PersonaKit grounding happens before external skill selection.

        ## Authorization Rules

        1. Only PersonaKit-declared skills may be considered for authorization.
        2. Any host-local or external skill that is not declared in PersonaKit is unauthorized by default.
        3. Persona `allowedSkillIds` define the execution ceiling.
        4. Persona `forbiddenSkillIds` act as a hard deny list.
        5. Required skills from kits, directives, and intents must fit inside the authorized set.
        6. If a needed skill is unauthorized, execution stops and requires re-grounding, reassignment, or human intervention.
        7. Review personas do not expand the active lane's skill authority.

        ## Trusted Behavior

        1. Resolve the active contract from PersonaKit first.
        2. Use only skills authorized by that resolved contract.
        3. Stop on mismatch rather than substituting or improvising with undeclared context.
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

func resolveSystemEssentialOverrideURL(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> URL? {
  guard let rootURL = activeRootURL(for: scopes) else {
    return nil
  }

  let fileURL = rootURL.appendingPathComponent(SystemEssentials.expectedPath(for: essentialId))

  guard fileManager.fileExists(atPath: fileURL.path) else {
    return nil
  }

  return fileURL
}

func resolveSystemEssential(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> ResolvedEssential? {
  if let overrideURL = resolveSystemEssentialOverrideURL(
    essentialId,
    scopes: scopes,
    fileManager: fileManager
  ) {
    return ResolvedEssential(
      id: essentialId,
      url: overrideURL,
      content: nil,
      source: .file
    )
  }

  guard
    let content = SystemEssentials.builtInContent(for: essentialId),
    let rootURL = activeRootURL(for: scopes)
  else {
    return nil
  }

  return ResolvedEssential(
    id: essentialId,
    url: rootURL.appendingPathComponent(SystemEssentials.expectedPath(for: essentialId)),
    content: content,
    source: .systemBuiltIn
  )
}

func resolveReferencedEssential(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> ResolvedEssential? {
  if SystemEssentials.injectedEssentialIds.contains(essentialId) {
    return resolveSystemEssential(
      essentialId,
      scopes: scopes,
      fileManager: fileManager
    )
  }

  guard let fileURL = resolveEssentialURL(essentialId, scopes: scopes, fileManager: fileManager)
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

/// Resolves an essential id to the first existing file in scope resolution order.
func resolveEssentialURL(
  _ essentialId: String,
  scopes: ScopeSet,
  fileManager: FileManager
) -> URL? {
  let expectedPath = SystemEssentials.expectedPath(for: essentialId)

  for root in scopes.resolutionOrder {
    let fileURL = root.appendingPathComponent(expectedPath)

    if fileManager.fileExists(atPath: fileURL.path) {
      return fileURL
    }
  }

  return nil
}
