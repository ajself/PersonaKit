import Foundation

struct Persona: Codable {
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

struct Kit: Codable {
    let id: String
    let version: String
    let name: String
    let summary: String
    let essentialIds: [String]
    let intentTemplateIds: [String]?
    let skillIds: [String]?
}

struct Task: Codable {
    struct Step: Codable {
        let text: String
        let requiresReview: Bool?
    }

    struct VerificationItem: Codable {
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

struct IntentTemplate: Codable {
    struct Parameter: Codable {
        let name: String
        let type: String
        let required: Bool
    }

    struct Risk: Codable {
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

struct Skill: Codable {
    struct Risk: Codable {
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

struct EssentialDocument {
    let id: String
    let content: String
}
