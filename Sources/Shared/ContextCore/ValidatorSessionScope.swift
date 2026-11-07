import Foundation

/// The session a handoff is built for. Scoped validation blocks only on errors in what this session reads.
public struct ValidationSessionScope: Equatable, Sendable {
  /// The session file's id, or nil for a persona + directive handoff with no session file.
  public let sessionId: String?
  public let personaId: String
  public let directiveId: String
  public let kitOverrides: [String]

  public init(
    sessionId: String?,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) {
    self.sessionId = sessionId
    self.personaId = personaId
    self.directiveId = directiveId
    self.kitOverrides = kitOverrides
  }
}

/// The entities a session reaches through its persona, directive, kits, and skills.
struct ValidationSessionReach {
  private let scope: ValidationSessionScope
  private let kitIds: Set<String>
  private let skillIds: Set<String>
  private let workstreamId: String?
  /// The directive a conflict in the session's workstream is reported on: the lowest id sharing it.
  private let workstreamRepresentativeId: String?

  init(scope: ValidationSessionScope, registry: Registry) {
    let persona = registry.personasById[scope.personaId]
    let directive = registry.directivesById[scope.directiveId]
    let kitIds = Set((persona?.defaultKitIds ?? []) + scope.kitOverrides)

    var skillIds = Set(directive?.requiresSkillIds ?? [])
    skillIds.formUnion(persona?.allowedSkillIds ?? [])
    skillIds.formUnion(persona?.forbiddenSkillIds ?? [])

    for kitId in kitIds {
      skillIds.formUnion(registry.kitsById[kitId]?.skillIds ?? [])
    }

    self.scope = scope
    self.kitIds = kitIds
    self.skillIds = skillIds
    let workstreamId = directive?.workstream?.id
    self.workstreamId = workstreamId
    self.workstreamRepresentativeId =
      workstreamId == nil
      ? nil
      : registry.directives.filter { $0.workstream?.id == workstreamId }.map(\.id).min()
  }

  /// Fields `ValidatorWorkstreamValidator.consistencyErrors` reports a cross-directive conflict under.
  private static let workstreamConsistencyFields: Set<String> = [
    "workstream.nodes",
    "workstream.edges",
    "workstream.entrySessionId",
    "workstream.requiredCloseoutSessionId",
  ]

  /// Whether `error` blocks this session's handoff. An error tied to no entity always does.
  func contains(_ error: ValidationError) -> Bool {
    guard let entityId = error.entityId else {
      return true
    }

    switch error.entityType {
    case .packsRoot:
      return true
    case .session:
      return entityId == scope.sessionId
    case .persona:
      return entityId == scope.personaId
    case .directive:
      if entityId == scope.directiveId {
        return true
      }

      // A workstream conflict is reported on one directive but involves every directive sharing the workstream.
      return entityId == workstreamRepresentativeId
        && error.missingId == workstreamId
        && Self.workstreamConsistencyFields.contains(error.field)
    case .kit:
      return kitIds.contains(entityId)
    case .skill:
      return skillIds.contains(entityId)
    }
  }
}
