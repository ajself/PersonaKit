import Foundation
import Testing

@testable import ContextCore

struct GroundingSkillMatcherTests {
  private func skill(
    id: String,
    triggerRules: [SkillTriggerRule]
  ) -> ResolvedGroundingSkill {
    ResolvedGroundingSkill(
      id: id,
      name: id,
      description: "",
      triggerRules: triggerRules,
      sources: []
    )
  }

  @Test
  func emptyRuleSkillExpandsOnEmptyInput() {
    let alwaysOn = skill(id: "always-on", triggerRules: [SkillTriggerRule()])
    let matches = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: [alwaysOn],
      input: SkillTriggerSelectionInput(targetPaths: [], skillTags: [])
    )

    #expect(matches.map(\.id) == ["always-on"])
  }

  @Test
  func pathRuleSkillDoesNotExpandOnEmptyInput() {
    let pathTriggered = skill(
      id: "path-triggered",
      triggerRules: [SkillTriggerRule(pathGlobs: ["**/*.swift"])]
    )
    let matches = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: [pathTriggered],
      input: SkillTriggerSelectionInput(targetPaths: [], skillTags: [])
    )

    #expect(matches.isEmpty)
  }

  @Test
  func tagRuleSkillDoesNotExpandOnEmptyInput() {
    let tagTriggered = skill(
      id: "tag-triggered",
      triggerRules: [SkillTriggerRule(skillTags: ["swiftui"])]
    )
    let matches = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: [tagTriggered],
      input: SkillTriggerSelectionInput(targetPaths: [], skillTags: [])
    )

    #expect(matches.isEmpty)
  }

  @Test
  func emptyRuleSkillCoexistsWithPathRuleOnMatchingInput() {
    let alwaysOn = skill(id: "always-on", triggerRules: [SkillTriggerRule()])
    let pathTriggered = skill(
      id: "path-triggered",
      triggerRules: [SkillTriggerRule(pathGlobs: ["**/*.swift"])]
    )
    let matches = GroundingSkillSupport.resolveMatches(
      availableGroundingSkills: [alwaysOn, pathTriggered],
      input: SkillTriggerSelectionInput(targetPaths: ["Sources/App.swift"], skillTags: [])
    )

    #expect(matches.map(\.id) == ["always-on", "path-triggered"])
  }
}
