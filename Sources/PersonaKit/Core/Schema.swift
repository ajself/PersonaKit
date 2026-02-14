import Foundation

/// Persona definition loaded from `Packs/personas/*.persona.json`.
struct Persona: Codable, Sendable {
  let id: String
  let version: String
  let name: String
  let summary: String
  let responsibilities: [String]
  let values: [String]
  let nonGoals: [String]
  let defaultKitIds: [String]
  let allowedSkillIds: [String]
  let forbiddenSkillIds: [String]
}

/// Kit definition loaded from `Packs/kits/*.kit.json`.
struct Kit: Codable, Sendable {
  let id: String
  let version: String
  let name: String
  let summary: String
  let essentialIds: [String]
  let intentTemplateIds: [String]?
  let skillIds: [String]?
}

/// Directive definition loaded from `Packs/directives/*.directive.json`.
struct Directive: Codable, Sendable {
  /// Ordered directive step with optional human review gate.
  struct Step: Codable, Sendable {
    let text: String
    let requiresReview: Bool?
  }

  /// Verification checklist entry for a directive.
  struct VerificationItem: Codable, Sendable {
    let kind: String
    let text: String
  }

  let id: String
  let version: String
  let title: String
  let goal: String
  let steps: [Step]
  let acceptanceCriteria: [String]
  let verification: [VerificationItem]
  let requiresIntentTemplateIds: [String]
  let requiresSkillIds: [String]
}

/// Intent template loaded from `Packs/intents/*.intent.json`.
struct IntentTemplate: Codable, Sendable {
  /// Intent parameter contract exposed to downstream tools.
  struct Parameter: Codable, Sendable {
    let name: String
    let type: String
    let required: Bool
  }

  /// Risk metadata attached to an intent template.
  struct Risk: Codable, Sendable {
    let level: String
    let requiresHumanReview: Bool
    let notes: [String]
  }

  let id: String
  let version: String
  let name: String
  let description: String
  let parameters: [Parameter]
  let includesEssentialIds: [String]
  let requiresSkillIds: [String]
  let risk: Risk
}

/// Skill definition loaded from `Packs/skills/*.skill.json`.
struct Skill: Codable, Sendable {
  /// Risk metadata attached to a skill.
  struct Risk: Codable, Sendable {
    let level: String
    let requiresHumanReview: Bool
    let notes: [String]
  }

  let id: String
  let version: String
  let name: String
  let description: String
  let providedBy: [String]
  let risk: Risk
  let notes: [String]
}

/// In-memory essential markdown document content.
struct EssentialDocument: Sendable {
  let id: String
  let content: String
}
