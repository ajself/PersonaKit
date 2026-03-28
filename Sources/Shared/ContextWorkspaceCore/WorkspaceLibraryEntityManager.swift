import Foundation

/// Library JSON editing contract used by PersonaKit authoring flows.
public protocol WorkspaceLibraryEntityManaging: Sendable {
  func loadRawJSON(fileURL: URL) throws -> String

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws

  func destinationFileURL(
    workspaceURL: URL,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) throws -> URL

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

public extension WorkspaceLibraryEntityManaging {
  func destinationFileURL(
    workspaceURL: URL,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) throws -> URL {
    throw WorkspaceSnapshotBuildError(message: "destinationFileURL is not implemented.")
  }
}

/// Filesystem-backed library JSON manager for shared authoring workflows.
public struct WorkspaceLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  private let schemaValidator: any WorkspaceEntityJSONSchemaValidating
  private let dependencies: WorkspaceLibraryEntityManagerDependencies

  public init(
    schemaValidator: any WorkspaceEntityJSONSchemaValidating = WorkspaceEntityJSONSchemaValidator(),
    dependencies: WorkspaceLibraryEntityManagerDependencies = .live()
  ) {
    self.schemaValidator = schemaValidator
    self.dependencies = dependencies
  }

  public func loadRawJSON(fileURL: URL) throws -> String {
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

  public func validateRawJSON(
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

  public func destinationFileURL(
    workspaceURL: URL,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) throws -> URL {
    let projectScopeURL = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
      workspaceURL,
      directoryExists: dependencies.directoryExists
    )

    return projectScopeURL
      .appendingPathComponent("Packs/\(entityType.directoryName)")
      .appendingPathComponent("\(WorkspaceEntityIDPolicy.normalized(itemID))\(entityType.fileSuffix)")
  }

  public func saveRawJSON(
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

    let destinationURL = try destinationFileURL(
      workspaceURL: workspaceURL,
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

  public func copyGlobalItemToProject(
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
public struct WorkspaceLibraryEntityManagerDependencies: Sendable {
  public let directoryExists: @Sendable (URL) -> Bool
  public let createDirectory: @Sendable (URL) throws -> Void
  public let readData: @Sendable (URL) throws -> Data
  public let writeData: @Sendable (Data, URL) throws -> Void

  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    createDirectory: @escaping @Sendable (URL) throws -> Void,
    readData: @escaping @Sendable (URL) throws -> Data,
    writeData: @escaping @Sendable (Data, URL) throws -> Void
  ) {
    self.directoryExists = directoryExists
    self.createDirectory = createDirectory
    self.readData = readData
    self.writeData = writeData
  }

  public static func live() -> WorkspaceLibraryEntityManagerDependencies {
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
