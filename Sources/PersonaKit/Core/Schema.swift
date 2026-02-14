import Foundation

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

struct Kit: Codable, Sendable {
    let id: String
    let version: String
    let name: String
    let summary: String
    let essentialIds: [String]
    let intentTemplateIds: [String]?
    let skillIds: [String]?
}

struct Directive: Codable, Sendable {
    struct Step: Codable, Sendable {
        let text: String
        let requiresReview: Bool?
    }

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

struct IntentTemplate: Codable, Sendable {
    struct Parameter: Codable, Sendable {
        let name: String
        let type: String
        let required: Bool
    }

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

struct Skill: Codable, Sendable {
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

struct EssentialDocument: Sendable {
    let id: String
    let content: String
}
