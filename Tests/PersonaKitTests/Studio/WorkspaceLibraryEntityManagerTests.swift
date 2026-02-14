import Foundation
import PersonaKitCore
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
