import ContextCore
import Foundation
import StudioFoundation
import Testing

struct WorkspaceLibraryEntityFormAdapterTests {
  @Test
  func parseFormStateReadsMappedPersonaFields() throws {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .persona)

    let formState = try adapter.parseFormState(
      from:
        """
        {
          "allowedSkillIds" : [
            "swiftui-style",
            "swift-style"
          ],
          "defaultKitIds" : [
            "ajself-style-kit"
          ],
          "id" : "senior-swiftui-engineer",
          "name" : "Senior SwiftUI Engineer",
          "summary" : "Preserved in raw JSON."
        }
        """
    )

    #expect(formState.id == "senior-swiftui-engineer")
    #expect(formState.primaryText == "Senior SwiftUI Engineer")
    #expect(formState.secondaryText == "Preserved in raw JSON.")
    #expect(formState.firstArrayLines == "ajself-style-kit")
    #expect(formState.secondArrayLines == "swiftui-style\nswift-style")
  }

  @Test
  func applyFormStateUpdatesMappedFieldsAndPreservesOtherData() throws {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .persona)
    let updatedRawJSON = try adapter.applyFormState(
      WorkspaceLibraryEntityFormState(
        id: "persona-new",
        primaryText: "Updated Name",
        secondaryText: "Updated summary.",
        firstArrayLines: "kit-one\nkit-two",
        secondArrayLines: "skill-a\n\nskill-b"
      ),
      to:
        """
        {
          "allowedSkillIds" : [
            "old-skill"
          ],
          "defaultKitIds" : [
            "old-kit"
          ],
          "id" : "persona-old",
          "name" : "Old Name",
          "summary" : "Keep me."
        }
        """
    )

    let jsonData = Data(updatedRawJSON.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
    let dictionary = try #require(jsonObject as? [String: Any])

    #expect(dictionary["id"] as? String == "persona-new")
    #expect(dictionary["name"] as? String == "Updated Name")
    #expect(dictionary["summary"] as? String == "Updated summary.")
    #expect(dictionary["defaultKitIds"] as? [String] == ["kit-one", "kit-two"])
    #expect(dictionary["allowedSkillIds"] as? [String] == ["skill-a", "skill-b"])
  }

  @Test
  func kitFormStateUpdatesSummaryField() throws {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .kit)
    let updatedRawJSON = try adapter.applyFormState(
      WorkspaceLibraryEntityFormState(
        id: "kit-new",
        primaryText: "Kit New",
        secondaryText: "Shared guidance for new work.",
        firstArrayLines: "essential-a",
        secondArrayLines: "skill-a"
      ),
      to:
        """
        {
          "essentialIds" : [],
          "id" : "",
          "name" : "",
          "summary" : "",
          "version" : "1.0"
        }
        """
    )

    let jsonData = Data(updatedRawJSON.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
    let dictionary = try #require(jsonObject as? [String: Any])

    #expect(dictionary["summary"] as? String == "Shared guidance for new work.")
  }

  @Test
  func directiveFormStateMapsGoalField() throws {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .directive)
    let formState = try adapter.parseFormState(
      from:
        """
        {
          "acceptanceCriteria" : [],
          "goal" : "Ship a focused change.",
          "id" : "directive-a",
          "requiresIntentTemplateIds" : [],
          "requiresSkillIds" : [],
          "steps" : [],
          "title" : "Directive A",
          "verification" : [],
          "version" : "1.0"
        }
        """
    )

    #expect(formState.secondaryText == "Ship a focused change.")

    let updatedRawJSON = try adapter.applyFormState(
      WorkspaceLibraryEntityFormState(
        id: "directive-a",
        primaryText: "Directive A",
        secondaryText: "Keep the goal explicit.",
        firstArrayLines: "",
        secondArrayLines: ""
      ),
      to:
        """
        {
          "goal" : "",
          "id" : "directive-a",
          "requiresIntentTemplateIds" : [],
          "requiresSkillIds" : [],
          "title" : "Directive A",
          "version" : "1.0"
        }
        """
    )

    let dictionary = try jsonDictionary(from: updatedRawJSON)
    #expect(dictionary["goal"] as? String == "Keep the goal explicit.")
  }

  @Test
  func intentAndSkillFormStatesMapDescriptionField() throws {
    let intentAdapter = WorkspaceLibraryEntityFormAdapter(entityType: .intent)
    let intentFormState = try intentAdapter.parseFormState(
      from:
        """
        {
          "description" : "Describe the user request.",
          "id" : "intent-a",
          "includesEssentialIds" : [],
          "name" : "Intent A",
          "parameters" : [],
          "requiresSkillIds" : [],
          "risk" : {
            "level" : "medium",
            "notes" : [],
            "requiresHumanReview" : false
          },
          "version" : "1.0"
        }
        """
    )

    #expect(intentFormState.secondaryText == "Describe the user request.")

    let updatedIntentRawJSON = try intentAdapter.applyFormState(
      WorkspaceLibraryEntityFormState(
        id: "intent-a",
        primaryText: "Intent A",
        secondaryText: "Updated intent description.",
        firstArrayLines: "",
        secondArrayLines: ""
      ),
      to:
        """
        {
          "description" : "",
          "id" : "intent-a",
          "includesEssentialIds" : [],
          "name" : "Intent A",
          "version" : "1.0"
        }
        """
    )

    let skillAdapter = WorkspaceLibraryEntityFormAdapter(entityType: .skill)
    let updatedSkillRawJSON = try skillAdapter.applyFormState(
      WorkspaceLibraryEntityFormState(
        id: "skill-a",
        primaryText: "Skill A",
        secondaryText: "Updated skill description.",
        firstArrayLines: "host-app",
        secondArrayLines: ""
      ),
      to:
        """
        {
          "description" : "",
          "id" : "skill-a",
          "name" : "Skill A",
          "notes" : [],
          "providedBy" : [],
          "version" : "1.0"
        }
        """
    )

    let intentDictionary = try jsonDictionary(from: updatedIntentRawJSON)
    let skillDictionary = try jsonDictionary(from: updatedSkillRawJSON)

    #expect(intentDictionary["description"] as? String == "Updated intent description.")
    #expect(skillDictionary["description"] as? String == "Updated skill description.")
  }

  @Test
  func parseFormStateRejectsInvalidJSON() {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .persona)
    let formState = try? adapter.parseFormState(from: "{")

    #expect(formState == nil)
  }

  private func jsonDictionary(
    from rawJSON: String
  ) throws -> [String: Any] {
    let jsonData = Data(rawJSON.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
    return try #require(jsonObject as? [String: Any])
  }
}
