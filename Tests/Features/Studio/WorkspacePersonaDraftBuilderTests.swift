import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

struct WorkspacePersonaDraftBuilderTests {
  @Test
  func buildRawJSONEmitsRequiredFieldsDeterministically() throws {
    let builder = WorkspacePersonaDraftBuilder()
    let draft = WorkspacePersonaDraft(
      id: " persona-a ",
      name: " Senior SwiftUI Engineer ",
      summary: " Pragmatic, accessibility-first, small diffs. ",
      responsibilities: [
        " Implement SwiftUI features ",
        "",
        " Write tests for changes ",
      ],
      values: [
        " correctness over cleverness ",
        " clarity ",
      ],
      nonGoals: [
        " architecture rewrites "
      ],
      defaultKitIds: [
        "kit-b",
        "kit-a",
        "kit-a",
        "",
      ],
      allowedSkillIds: [
        "skill-b",
        "skill-a",
        "skill-a",
      ],
      forbiddenSkillIds: [
        "skill-z",
        "skill-z",
      ]
    )

    let firstRawJSON = try builder.buildRawJSON(draft: draft)
    let secondRawJSON = try builder.buildRawJSON(draft: draft)

    #expect(firstRawJSON == secondRawJSON)
    #expect(firstRawJSON.hasSuffix("\n"))

    let jsonData = Data(firstRawJSON.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
    let dictionary = try #require(jsonObject as? [String: Any])

    #expect(
      Set(dictionary.keys)
        == Set(
          [
            "allowedSkillIds",
            "defaultKitIds",
            "forbiddenSkillIds",
            "id",
            "name",
            "nonGoals",
            "responsibilities",
            "summary",
            "values",
            "version",
          ]
        )
    )
    #expect(dictionary["id"] as? String == "persona-a")
    #expect(dictionary["version"] as? String == "1.0")
    #expect(dictionary["name"] as? String == "Senior SwiftUI Engineer")
    #expect(dictionary["summary"] as? String == "Pragmatic, accessibility-first, small diffs.")
    #expect(dictionary["responsibilities"] as? [String] == ["Implement SwiftUI features", "Write tests for changes"])
    #expect(dictionary["values"] as? [String] == ["correctness over cleverness", "clarity"])
    #expect(dictionary["nonGoals"] as? [String] == ["architecture rewrites"])
    #expect(dictionary["defaultKitIds"] as? [String] == ["kit-a", "kit-b"])
    #expect(dictionary["allowedSkillIds"] as? [String] == ["skill-a", "skill-b"])
    #expect(dictionary["forbiddenSkillIds"] as? [String] == ["skill-z"])
  }

  @Test
  func validateReportsUnknownReferenceWarnings() {
    let builder = WorkspacePersonaDraftBuilder()
    let validation = builder.validate(
      draft: WorkspacePersonaDraft(
        id: "persona-a",
        name: "Persona A",
        summary: "Summary",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: ["missing-kit"],
        allowedSkillIds: ["missing-allowed-skill"],
        forbiddenSkillIds: ["missing-forbidden-skill"]
      ),
      existingPersonaIDs: [],
      knownKitIDs: [],
      knownSkillIDs: []
    )

    #expect(validation.errors.isEmpty)
    #expect(
      validation.warnings
        == [
          "Unknown kit ids: missing-kit.",
          "Unknown allowed skill ids: missing-allowed-skill.",
          "Unknown forbidden skill ids: missing-forbidden-skill.",
        ]
    )
  }

  @Test
  func buildRawJSONRejectsInvalidID() {
    let builder = WorkspacePersonaDraftBuilder()

    do {
      _ = try builder.buildRawJSON(
        draft: WorkspacePersonaDraft(
          id: "../invalid",
          name: "Persona A",
          summary: "Summary",
          responsibilities: [],
          values: [],
          nonGoals: [],
          defaultKitIds: [],
          allowedSkillIds: [],
          forbiddenSkillIds: []
        )
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("is not valid"))
    } catch {
      #expect(Bool(false))
    }
  }

  @Test
  func buildRawJSONRejectsOverlappingAllowedAndForbiddenSkills() {
    let builder = WorkspacePersonaDraftBuilder()

    do {
      _ = try builder.buildRawJSON(
        draft: WorkspacePersonaDraft(
          id: "persona-a",
          name: "Persona A",
          summary: "Summary",
          responsibilities: [],
          values: [],
          nonGoals: [],
          defaultKitIds: [],
          allowedSkillIds: ["skill-a"],
          forbiddenSkillIds: ["skill-a"]
        )
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("cannot overlap"))
    } catch {
      #expect(Bool(false))
    }
  }

  @Test
  func buildRawJSONRejectsDuplicatePersonaID() {
    let builder = WorkspacePersonaDraftBuilder()

    do {
      _ = try builder.buildRawJSON(
        draft: WorkspacePersonaDraft(
          id: "persona-a",
          name: "Persona A",
          summary: "Summary",
          responsibilities: [],
          values: [],
          nonGoals: [],
          defaultKitIds: [],
          allowedSkillIds: [],
          forbiddenSkillIds: []
        ),
        existingPersonaIDs: Set(["persona-a"])
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("already exists"))
    } catch {
      #expect(Bool(false))
    }
  }
}
