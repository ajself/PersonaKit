import ContextCore
import ContextWorkspaceCore
import Foundation

enum OrbitContractResolutionError: LocalizedError, Equatable {
  case missingProjectScope
  case resolutionFailed([String])

  var errorDescription: String? {
    switch self {
    case .missingProjectScope:
      return "the active workspace is missing a readable PersonaKit scope"
    case .resolutionFailed(let messages):
      return messages.joined(separator: "; ")
    }
  }
}

enum OrbitContractResolver {
  static func resolve(
    participant: OrbitParticipant,
    workspaceURL: URL,
    fileManager: FileManager = .default
  ) throws -> OrbitResolvedActivationContract {
    guard let personaTemplateID = participant.personaTemplateID else {
      return OrbitResolvedActivationContract(
        directiveID: participant.defaultDirectiveID,
        directiveSource: .participantDefault,
        kitIDs: [],
        authorizedSkillIDs: participant.authorizedSkillIDs,
        requiredSkillIDs: participant.requiredSkillIDs,
        stopPointIDs: [],
        reviewGateIDs: [],
        memoryScopeIDs: [],
        failureReasons: []
      )
    }

    let scopeResolver = WorkspaceScopeResolver(directoryExists: { url in
      WorkspaceScopeResolver.directoryExists(url)
    })
    let projectScopeURL: URL

    do {
      projectScopeURL = try scopeResolver.resolveProjectScopeURL(workspaceURL)
    } catch is MissingPersonaKitDirectoryError {
      throw OrbitContractResolutionError.missingProjectScope
    }
    let scopes = ScopeSet(
      projectScopeURL: projectScopeURL,
      globalScopeURL: WorkspaceScopeResolver.defaultGlobalScopeURL(fileManager: fileManager)
    )

    let resolved: SessionContractResult

    do {
      resolved = try SessionContractResolver.resolve(
        scopes: scopes,
        personaId: personaTemplateID,
        directiveId: participant.defaultDirectiveID,
        kitOverrides: [],
        requestedSkillIds: participant.requiredSkillIDs,
        fileManager: fileManager
      )
    } catch let error as ResolverResolutionError {
      throw OrbitContractResolutionError.resolutionFailed(error.errors.map(\.message))
    }

    return OrbitResolvedActivationContract(
      directiveID: resolved.directive?.id,
      directiveSource: .participantDefault,
      kitIDs: resolved.kits.map { $0.id }.sorted(),
      authorizedSkillIDs: resolved.skillAuthorization.authorizedSkillIds,
      requiredSkillIDs: resolved.skillAuthorization.requiredSkillIds,
      stopPointIDs: resolved.directive?.steps.filter { $0.requiresReview == true }.map { $0.text } ?? [],
      reviewGateIDs: reviewGateIDs(from: resolved),
      memoryScopeIDs: memoryScopeIDs(from: resolved),
      failureReasons: resolved.skillAuthorization.failureReasons
    )
  }

  private static func reviewGateIDs(
    from resolved: SessionContractResult
  ) -> [String] {
    let intentReviewGates = resolved.intents
      .filter { $0.risk.requiresHumanReview }
      .map { "intent:\($0.id)" }
    let skillReviewGates = resolved.skills
      .filter { $0.risk.requiresHumanReview }
      .map { "skill:\($0.id)" }

    return Array(Set(intentReviewGates + skillReviewGates)).sorted()
  }

  private static func memoryScopeIDs(
    from resolved: SessionContractResult
  ) -> [String] {
    resolved.essentials
      .map { $0.id }
      .filter { $0.localizedCaseInsensitiveContains("memory") }
      .sorted()
  }
}
