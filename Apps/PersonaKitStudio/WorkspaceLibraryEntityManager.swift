import Foundation
import PersonaKitCore

/// Library JSON editing contract used by `WorkspaceStore`.
protocol WorkspaceLibraryEntityManaging: Sendable {
  func loadRawJSON(fileURL: URL) throws -> String

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws
}

/// Filesystem-backed library JSON manager for Studio raw editing workflows.
struct WorkspaceLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  private let schemaValidator: any WorkspaceEntityJSONSchemaValidating
  private let dependencies: WorkspaceLibraryEntityManagerDependencies

  init(
    schemaValidator: any WorkspaceEntityJSONSchemaValidating = WorkspaceEntityJSONSchemaValidator(),
    dependencies: WorkspaceLibraryEntityManagerDependencies = .live()
  ) {
    self.schemaValidator = schemaValidator
    self.dependencies = dependencies
  }

  func loadRawJSON(fileURL: URL) throws -> String {
    do {
      let data = try dependencies.readData(fileURL)

      guard let rawJSON = String(data: data, encoding: .utf8) else {
        throw WorkspaceSnapshotBuildError(
          message: "File is not valid UTF-8 JSON text."
        )
      }

      return rawJSON
    } catch let error as WorkspaceSnapshotBuildError {
      throw error
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to load JSON: \(error.localizedDescription)"
      )
    }
  }

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws {
    let normalizedExpectedID = WorkspaceEntityIDPolicy.normalized(expectedID)

    guard WorkspaceEntityIDPolicy.isValid(normalizedExpectedID) else {
      throw WorkspaceSnapshotBuildError(
        message:
          "Entity id \"\(normalizedExpectedID)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
      )
    }

    let jsonData = Data(rawJSON.utf8)
    try schemaValidator.validate(
      jsonData: jsonData,
      entityType: entityType
    )

    let actualID = try extractID(from: jsonData)

    guard actualID == normalizedExpectedID else {
      throw WorkspaceSnapshotBuildError(
        message: "JSON id mismatch. Expected \"\(normalizedExpectedID)\" but found \"\(actualID)\"."
      )
    }
  }

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    let normalizedItemID = WorkspaceEntityIDPolicy.normalized(itemID)

    try validateRawJSON(
      rawJSON,
      entityType: entityType,
      expectedID: normalizedItemID
    )

    let projectScopeURL = try resolveProjectScopeURL(workspaceURL)
    let destinationURL = destinationFileURL(
      projectScopeURL: projectScopeURL,
      itemID: normalizedItemID,
      entityType: entityType
    )
    let destinationDirectory = destinationURL.deletingLastPathComponent()

    do {
      try dependencies.createDirectory(destinationDirectory)
      try dependencies.writeData(Data(rawJSON.utf8), destinationURL)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to save JSON: \(error.localizedDescription)"
      )
    }
  }

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    guard item.sourceScope == .global else {
      throw WorkspaceSnapshotBuildError(
        message: "Copy to Project is only available for global items."
      )
    }

    let rawJSON = try loadRawJSON(fileURL: item.fileURL)
    try saveRawJSON(
      workspaceURL: workspaceURL,
      itemID: item.id,
      rawJSON: rawJSON,
      entityType: entityType
    )
  }

  private func resolveProjectScopeURL(_ workspaceURL: URL) throws -> URL {
    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL: URL

    if workspace.lastPathComponent == ".personakit" {
      projectScopeURL = workspace
    } else {
      projectScopeURL = workspace.appendingPathComponent(".personakit")
    }

    let packsURL = projectScopeURL.appendingPathComponent("Packs")

    guard dependencies.directoryExists(packsURL) else {
      throw WorkspaceSnapshotBuildError(
        message: "Missing PersonaKit directory at \(projectScopeURL.path())."
      )
    }

    return projectScopeURL
  }

  private func destinationFileURL(
    projectScopeURL: URL,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) -> URL {
    projectScopeURL
      .appendingPathComponent("Packs/\(entityType.directoryName)")
      .appendingPathComponent("\(itemID)\(entityType.fileSuffix)")
  }

  private func extractID(from jsonData: Data) throws -> String {
    let jsonObject: Any

    do {
      jsonObject = try JSONSerialization.jsonObject(with: jsonData)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Invalid JSON: \(error.localizedDescription)"
      )
    }

    guard let dictionary = jsonObject as? [String: Any] else {
      throw WorkspaceSnapshotBuildError(
        message: "JSON root must be an object."
      )
    }

    guard let id = dictionary["id"] as? String else {
      throw WorkspaceSnapshotBuildError(
        message: "JSON id field is required."
      )
    }

    return id
  }
}

/// Injectable filesystem behavior for library JSON editing.
struct WorkspaceLibraryEntityManagerDependencies {
  let directoryExists: @Sendable (URL) -> Bool
  let createDirectory: @Sendable (URL) throws -> Void
  let readData: @Sendable (URL) throws -> Data
  let writeData: @Sendable (Data, URL) throws -> Void

  static func live() -> WorkspaceLibraryEntityManagerDependencies {
    WorkspaceLibraryEntityManagerDependencies(
      directoryExists: { url in
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      createDirectory: { url in
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
      },
      readData: { url in
        try Data(contentsOf: url)
      },
      writeData: { data, url in
        try data.write(to: url, options: [.atomic])
      }
    )
  }
}
