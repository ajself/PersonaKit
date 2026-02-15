import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitStudio

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
    #expect(dictionary["defaultKitIds"] as? [String] == ["kit-one", "kit-two"])
    #expect(dictionary["allowedSkillIds"] as? [String] == ["skill-a", "skill-b"])
    #expect(dictionary["summary"] as? String == "Keep me.")
  }

  @Test
  func parseFormStateRejectsInvalidJSON() {
    let adapter = WorkspaceLibraryEntityFormAdapter(entityType: .persona)
    let formState = try? adapter.parseFormState(from: "{")

    #expect(formState == nil)
  }
}
