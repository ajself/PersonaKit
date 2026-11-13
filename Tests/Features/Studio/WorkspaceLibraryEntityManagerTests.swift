import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import PersonaKitStudio

struct WorkspaceLibraryEntityManagerTests {
  @Test
  func validateRawJSONRejectsMismatchedID() throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: WorkspaceLibraryEntityManagerDependencies(
        directoryExists: { _ in true },
        createDirectory: { _ in },
        readData: { _ in Data() },
        writeData: { _, _ in }
      )
    )

    do {
      try manager.validateRawJSON(
        """
        {
          "id": "persona-b"
        }
        """,
        entityType: .persona,
        expectedID: "persona-a"
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("JSON id mismatch"))
    }
  }

  @Test
  func saveRawJSONWritesToProjectScopeEntityPath() throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    try manager.saveRawJSON(
      workspaceURL: workspaceURL,
      itemID: "persona-a",
      rawJSON:
        """
          {
            "id": "persona-a"
          }
        """,
      entityType: .persona
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/personas/persona-a.persona.json")
    let writtenData = try Data(contentsOf: destinationURL)

    #expect(String(data: writtenData, encoding: .utf8)?.contains("\"id\": \"persona-a\"") == true)
  }

  @Test
  func saveRawJSONFailsWhenProjectPacksPathIsFile() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: WorkspaceLibraryEntityManagerDependencies(
        directoryExists: { _ in false },
        fileExists: { url in
          url.standardizedFileURL == packsURL.standardizedFileURL
        },
        createDirectory: { _ in },
        readData: { _ in Data() },
        writeData: { _, _ in }
      )
    )

    do {
      try manager.saveRawJSON(
        workspaceURL: workspaceURL,
        itemID: "persona-a",
        rawJSON:
          """
            {
              "id": "persona-a"
            }
          """,
        entityType: .persona
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message == "PersonaKit reserved path Packs exists but is not a directory.")
    }
  }

  @Test
  func saveRawJSONRejectsUnsafeItemID() throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    do {
      try manager.saveRawJSON(
        workspaceURL: workspaceURL,
        itemID: "../persona-a",
        rawJSON:
          """
          {
            "id": "../persona-a"
          }
          """,
        entityType: .persona
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("is not valid"))
    }
  }

  @Test
  func destinationFileURLRejectsUnsafeItemID() throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    do {
      _ = try manager.destinationFileURL(
        workspaceURL: workspaceURL,
        itemID: "../persona-a",
        entityType: .persona
      )
      Issue.record("Expected destinationFileURL to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("is not valid"))
    }
  }

  @Test
  func copyGlobalItemToProjectWritesProjectFile() throws {
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    let globalRootURL = try makeTempDirectory()
    let globalFileURL =
      globalRootURL
      .appendingPathComponent("Packs/personas/persona-a.persona.json")
    try FileManager.default.createDirectory(
      at: globalFileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let sourceData = Data(
      """
      {
        "id": "persona-a"
      }
      """.utf8
    )
    try sourceData.write(to: globalFileURL, options: [.atomic])

    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: .live()
    )

    try manager.copyGlobalItemToProject(
      workspaceURL: workspaceURL,
      item: WorkspaceListItem(
        id: "persona-a",
        displayName: "Persona A",
        fileURL: globalFileURL,
        sourceScope: .global
      ),
      entityType: .persona
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/personas/persona-a.persona.json")
    #expect(FileManager.default.fileExists(atPath: destinationURL.path()))
  }

  @Test
  func copyGlobalSkillToProjectCopiesItsBody() throws {
    let fixture = try SkillCopyFixture(globalBody: "# Style\n\nUse tabs.\n")

    try fixture.copy()

    #expect(FileManager.default.fileExists(atPath: fixture.projectJSONURL.path(percentEncoded: false)))
    #expect(try String(contentsOf: fixture.projectBodyURL, encoding: .utf8) == "# Style\n\nUse tabs.\n")
  }

  @Test
  func copyGlobalSkillWithoutBodyCopiesOnlyItsJSON() throws {
    let fixture = try SkillCopyFixture(globalBody: nil)

    try fixture.copy()

    #expect(FileManager.default.fileExists(atPath: fixture.projectJSONURL.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: fixture.projectBodyURL.path(percentEncoded: false)))
  }

  @Test
  func copyGlobalSkillRefusesToReplaceAnExistingProjectBody() throws {
    let fixture = try SkillCopyFixture(globalBody: "global body\n")
    try FileManager.default.createDirectory(
      at: fixture.projectBodyURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("project body\n".utf8).write(to: fixture.projectBodyURL)

    do {
      try fixture.copy()
      Issue.record("Expected the copy to refuse.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains(fixture.projectBodyURL.path(percentEncoded: false)))
    }

    #expect(try String(contentsOf: fixture.projectBodyURL, encoding: .utf8) == "project body\n")
    #expect(!FileManager.default.fileExists(atPath: fixture.projectJSONURL.path(percentEncoded: false)))
  }

  @Test
  func copyGlobalSkillWithInvalidJSONLeavesNoBodyBehind() throws {
    struct SchemaFailure: Error {}
    let fixture = try SkillCopyFixture(globalBody: "global body\n")

    #expect(throws: (any Error).self) {
      try fixture.copy(validateHandler: { _, _ in throw SchemaFailure() })
    }

    #expect(!FileManager.default.fileExists(atPath: fixture.projectBodyURL.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: fixture.projectJSONURL.path(percentEncoded: false)))
  }

  @Test
  func saveRawJSONWritesToProjectScopeSkillPath() throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: { _, _ in }),
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    try manager.saveRawJSON(
      workspaceURL: workspaceURL,
      itemID: "swift-style-guide-reference",
      rawJSON:
        """
          {
            "id": "swift-style-guide-reference"
          }
        """,
      entityType: .skill
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/skills/swift-style-guide-reference.skill.json")

    #expect(FileManager.default.fileExists(atPath: destinationURL.path()))
  }
}

private struct StubEntitySchemaValidator: WorkspaceEntityJSONSchemaValidating, Sendable {
  let validateHandler: @Sendable (Data, WorkspaceLibraryEntityType) throws -> Void

  func validate(
    jsonData: Data,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try validateHandler(jsonData, entityType)
  }
}

/// A global skill and an empty project, both under folders with spaces, as the live file system sees them.
private struct SkillCopyFixture {
  let workspaceURL: URL
  let globalJSONURL: URL
  let projectJSONURL: URL
  let projectBodyURL: URL

  init(globalBody: String?) throws {
    workspaceURL = try makeTempDirectory().appendingPathComponent("my workspace")
    try FileManager.default.createDirectory(
      at: workspaceURL.appendingPathComponent(".personakit/Packs"),
      withIntermediateDirectories: true
    )

    let globalSkillsURL = try makeTempDirectory().appendingPathComponent("global library/Packs/skills")
    try FileManager.default.createDirectory(at: globalSkillsURL, withIntermediateDirectories: true)
    globalJSONURL = globalSkillsURL.appendingPathComponent("style-guide.skill.json")
    try Data(#"{ "id": "style-guide" }"#.utf8).write(to: globalJSONURL)
    if let globalBody {
      try Data(globalBody.utf8).write(to: globalSkillsURL.appendingPathComponent("style-guide.md"))
    }

    let projectSkillsURL = workspaceURL.appendingPathComponent(".personakit/Packs/skills")
    projectJSONURL = projectSkillsURL.appendingPathComponent("style-guide.skill.json")
    projectBodyURL = projectSkillsURL.appendingPathComponent("style-guide.md")
  }

  func copy(
    validateHandler: @escaping @Sendable (Data, WorkspaceLibraryEntityType) throws -> Void = { _, _ in }
  ) throws {
    let manager = WorkspaceLibraryEntityManager(
      schemaValidator: StubEntitySchemaValidator(validateHandler: validateHandler),
      dependencies: .live()
    )
    try manager.copyGlobalItemToProject(
      workspaceURL: workspaceURL,
      item: WorkspaceListItem(
        id: "style-guide",
        displayName: "Style Guide",
        fileURL: globalJSONURL,
        sourceScope: .global
      ),
      entityType: .skill
    )
  }
}
