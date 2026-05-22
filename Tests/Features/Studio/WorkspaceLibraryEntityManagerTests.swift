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
  func saveRawJSONWritesToProjectScopeReferencePath() throws {
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
      entityType: .reference
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/references/swift-style-guide-reference.reference.json")

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
