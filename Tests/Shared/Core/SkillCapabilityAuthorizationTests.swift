import Foundation
import Testing

@testable import ContextCore

struct SkillCapabilityAuthorizationTests {
  private func persona(forbiddenCapabilities: [String]?) -> Persona {
    Persona(
      id: "reviewer",
      version: "1.0",
      name: "Reviewer",
      summary: "",
      responsibilities: [],
      values: [],
      nonGoals: [],
      defaultKitIds: [],
      allowedSkillIds: ["editor"],
      forbiddenSkillIds: [],
      forbiddenCapabilities: forbiddenCapabilities
    )
  }

  @Test
  func forbiddenCapabilityUnauthorizesAnAllowedSkill() {
    let (contract, errors) = SessionContractSkillAuthorizationEvaluator.evaluate(
      persona: persona(forbiddenCapabilities: ["edit-files"]),
      requiredSkillReferences: [],
      declaredSkillIds: ["editor"],
      requestedSkillIds: [],
      skillCapabilitiesById: ["editor": ["edit-files"]]
    )

    #expect(!contract.isAuthorized)
    #expect(!contract.authorizedSkillIds.contains("editor"))
    #expect(
      contract.failureReasons.contains(
        "persona reviewer authorizes skill editor with capability edit-files forbidden by forbiddenCapabilities"
      )
    )
    #expect(errors.contains { if case .conflictingPersonaSkillCapability = $0 { return true }; return false })
  }

  @Test
  func nonConflictingCapabilityLeavesSkillAuthorized() {
    let (contract, errors) = SessionContractSkillAuthorizationEvaluator.evaluate(
      persona: persona(forbiddenCapabilities: ["network-access"]),
      requiredSkillReferences: [],
      declaredSkillIds: ["editor"],
      requestedSkillIds: [],
      skillCapabilitiesById: ["editor": ["edit-files"]]
    )

    #expect(contract.isAuthorized)
    #expect(contract.authorizedSkillIds == ["editor"])
    #expect(errors.isEmpty)
  }

  @Test
  func noForbiddenCapabilitiesIsBackwardCompatible() {
    let (contract, _) = SessionContractSkillAuthorizationEvaluator.evaluate(
      persona: persona(forbiddenCapabilities: nil),
      requiredSkillReferences: [],
      declaredSkillIds: ["editor"],
      requestedSkillIds: [],
      skillCapabilitiesById: ["editor": ["edit-files"]]
    )

    #expect(contract.isAuthorized)
    #expect(contract.authorizedSkillIds == ["editor"])
  }
}
