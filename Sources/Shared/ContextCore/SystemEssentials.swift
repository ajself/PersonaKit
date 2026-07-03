import Foundation

/// Built-in contract framings injected into every resolved PersonaKit session.
///
/// These are not authorable entities: the persona-activation framing renders
/// inline under `# Persona` and the skill-authorization framing under
/// `# Skill Contract`. The ids remain the stable handles reported as a session's
/// injected system contracts.
enum SystemFramings {
  static let personaActivationContractId = "persona-activation-contract"
  static let skillAuthorizationContractId = "skill-authorization-contract"

  /// Ids of the injected system contracts, in resolved-output order.
  static let injectedContractIds = [
    personaActivationContractId,
    skillAuthorizationContractId,
  ]

  /// Framing that governs how an operating persona is activated for a session.
  static let personaActivationFraming = """
    One active operating persona per lane; an assignment stays authoritative until explicitly replaced. Reassignment requires fresh grounding and prior assumptions must not carry forward. If authoritative grounding is unavailable, stop rather than blend or infer identity.
    """

  /// Framing that governs how declared skills are authorized for a session.
  static let skillAuthorizationFraming = """
    Only PersonaKit-declared skills are authorized; anything undeclared is unauthorized by default. Persona `allowedSkillIds` set the ceiling and `forbiddenSkillIds` hard-deny; a required-but-unauthorized skill stops execution. The resolved outcome is in `# Skill Contract`.
    """
}
