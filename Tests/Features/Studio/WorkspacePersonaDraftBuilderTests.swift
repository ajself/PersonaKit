import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

struct WorkspacePersonaDraftBuilderTests {
  private static func draft(environment: [String]?) -> WorkspacePersonaDraft {
    WorkspacePersonaDraft(
      id: "persona-a",
      name: "Persona A",
      summary: "Summary",
      responsibilities: [],
      values: [],
      nonGoals: [],
      environment: environment,
      defaultKitIds: [],
      allowedSkillIds: [],
      forbiddenSkillIds: []
    )
  }

  @Test
  func environmentSurvivesDraftSaveReloadOrderPreservingAndTrimmed() throws {
    let builder = WorkspacePersonaDraftBuilder()
    let json = try builder.buildRawJSON(
      draft: Self.draft(environment: [" Platform: macOS ", "", " Language: Swift "])
    )
    let reloaded = try JSONDecoder().decode(Persona.self, from: Data(json.utf8))
    // Order preserved, blanks dropped, entries trimmed — not sorted/deduped.
    #expect(reloaded.environment == ["Platform: macOS", "Language: Swift"])
  }

  @Test
  func absentEnvironmentStaysAbsentAndIsNotEmitted() throws {
    let builder = WorkspacePersonaDraftBuilder()
    let json = try builder.buildRawJSON(draft: Self.draft(environment: nil))
    let dictionary = try #require(
      JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    #expect(dictionary["environment"] == nil)
    let reloaded = try JSONDecoder().decode(Persona.self, from: Data(json.utf8))
    #expect(reloaded.environment == nil)
  }

  @Test
  func authoredEmptyEnvironmentIsEmittedAndDoesNotBecomeAbsent() throws {
    let builder = WorkspacePersonaDraftBuilder()
    let json = try builder.buildRawJSON(draft: Self.draft(environment: []))
    let dictionary = try #require(
      JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    // The empty list is a distinct authored value: it must be present as [], not omitted.
    #expect(dictionary["environment"] as? [String] == [])
    let reloaded = try JSONDecoder().decode(Persona.self, from: Data(json.utf8))
    #expect(reloaded.environment == [])
  }

  @Test
  func parseEditSaveIsIdempotentForEveryEnvironmentOptionality() throws {
    let builder = WorkspacePersonaDraftBuilder()
    for environment: [String]? in [nil, [], ["Platform: macOS", "Language: Swift"]] {
      // Parse a persona JSON into a draft, re-emit, and confirm byte-stability.
      let firstJSON = try builder.buildRawJSON(draft: Self.draft(environment: environment))
      let persona = try JSONDecoder().decode(Persona.self, from: Data(firstJSON.utf8))
      let reDraft = WorkspacePersonaDraft(
        id: persona.id,
        name: persona.name,
        summary: persona.summary,
        responsibilities: persona.responsibilities,
        values: persona.values,
        nonGoals: persona.nonGoals,
        environment: persona.environment,
        defaultKitIds: persona.defaultKitIds,
        allowedSkillIds: persona.allowedSkillIds,
        forbiddenSkillIds: persona.forbiddenSkillIds,
        forbiddenCapabilities: persona.forbiddenCapabilities ?? []
      )
      let secondJSON = try builder.buildRawJSON(draft: reDraft)
      #expect(firstJSON == secondJSON)
    }
  }

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

  @Test
  func buildRawJSONEmitsForbiddenCapabilitiesSortedAndDeduped() throws {
    let json = try WorkspacePersonaDraftBuilder().buildRawJSON(
      draft: WorkspacePersonaDraft(
        id: "ro",
        name: "RO",
        summary: "Read-only reviewer.",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: [],
        forbiddenCapabilities: ["run-commands", "edit-files", "edit-files"]
      )
    )
    let dictionary = try #require(
      JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    #expect(dictionary["forbiddenCapabilities"] as? [String] == ["edit-files", "run-commands"])
  }

  @Test
  func validateRejectsUnknownForbiddenCapability() {
    let validation = WorkspacePersonaDraftBuilder().validate(
      draft: WorkspacePersonaDraft(
        id: "ro",
        name: "RO",
        summary: "x",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: [],
        forbiddenCapabilities: ["file-editing"]
      )
    )

    #expect(!validation.isValid)
    #expect(validation.errors.contains { $0.contains("Unknown forbidden capabilities: file-editing") })
  }
}
