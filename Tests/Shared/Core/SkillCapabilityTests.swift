import Foundation
import Testing

@testable import ContextCore

struct SkillCapabilityTests {
  @Test
  func vocabularyMatchesSchemaEnum() throws {
    let json = try #require(PersonaKitSchema.json(for: "skill"))
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    let properties = try #require(object["properties"] as? [String: Any])
    let capabilities = try #require(properties["capabilities"] as? [String: Any])
    let items = try #require(capabilities["items"] as? [String: Any])
    let schemaEnum = try #require(items["enum"] as? [String])

    #expect(Set(schemaEnum) == Set(SkillCapability.vocabulary))
  }

  @Test
  func personaForbiddenCapabilitiesMatchesSchemaEnum() throws {
    let json = try #require(PersonaKitSchema.json(for: "persona"))
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    let properties = try #require(object["properties"] as? [String: Any])
    let forbidden = try #require(properties["forbiddenCapabilities"] as? [String: Any])
    let items = try #require(forbidden["items"] as? [String: Any])
    let schemaEnum = try #require(items["enum"] as? [String])

    #expect(Set(schemaEnum) == Set(SkillCapability.vocabulary))
  }

  @Test
  func isKnownRecognizesVocabularyAndRejectsOthers() {
    #expect(SkillCapability.isKnown("read-only-inspection"))
    #expect(SkillCapability.isKnown("edit-files"))
    #expect(!SkillCapability.isKnown("file-editing"))
    #expect(!SkillCapability.isKnown(""))
  }

  @Test
  func capabilitiesRoundTripAndOmitWhenAbsent() throws {
    let withCaps = Skill(
      id: "s",
      version: "1.0",
      name: "S",
      description: "",
      providedBy: [],
      capabilities: ["edit-files"],
      risk: Skill.Risk(level: "low", requiresHumanReview: false, notes: []),
      notes: []
    )
    let encoded = try JSONEncoder().encode(withCaps)
    let decoded = try JSONDecoder().decode(Skill.self, from: encoded)
    #expect(decoded.capabilities == ["edit-files"])

    // A skill JSON without the key decodes to nil (back-compatible with existing packs).
    let legacy = """
      {"id":"s","version":"1.0","name":"S","description":"",
       "providedBy":[],"risk":{"level":"low","requiresHumanReview":false,"notes":[]},"notes":[]}
      """
    let legacyDecoded = try JSONDecoder().decode(Skill.self, from: Data(legacy.utf8))
    #expect(legacyDecoded.capabilities == nil)
  }
}
