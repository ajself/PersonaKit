import ContextCore
import ContextWorkspaceCore
import Foundation

/// Essentials markdown editing contract used by `WorkspaceStore`.
public protocol WorkspaceEssentialManaging: Sendable {
  func loadMarkdown(fileURL: URL) throws -> String

  func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws
}

/// Filesystem-backed essentials manager for Studio markdown editing workflows.
public struct WorkspaceEssentialManager: WorkspaceEssentialManaging, Sendable {
  private let dependencies: WorkspaceEssentialManagerDependencies

  public init(
    dependencies: WorkspaceEssentialManagerDependencies = .live()
  ) {
    self.dependencies = dependencies
  }

  public func loadMarkdown(fileURL: URL) throws -> String {
    do {
      let data = try dependencies.readData(fileURL)

      guard let markdown = String(data: data, encoding: .utf8) else {
        throw WorkspaceSnapshotBuildError(
          message: "File is not valid UTF-8 markdown text."
        )
      }

      return markdown
    } catch let error as WorkspaceSnapshotBuildError {
      throw error
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to load markdown: \(error.localizedDescription)"
      )
    }
  }

  public func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {
    let normalizedItemID = WorkspaceEntityIDPolicy.normalized(itemID)

    guard WorkspaceEntityIDPolicy.isValid(normalizedItemID) else {
      throw WorkspaceSnapshotBuildError(
        message:
          "Essential id \"\(normalizedItemID)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
      )
    }

    let projectScopeURL = try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
      workspaceURL,
      directoryExists: dependencies.directoryExists
    )
    let destinationURL = destinationFileURL(
      projectScopeURL: projectScopeURL,
      itemID: normalizedItemID
    )
    let destinationDirectory = destinationURL.deletingLastPathComponent()

    do {
      try dependencies.createDirectory(destinationDirectory)
      try dependencies.writeData(Data(markdown.utf8), destinationURL)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to save markdown: \(error.localizedDescription)"
      )
    }
  }

  public func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {
    guard item.sourceScope == .global else {
      throw WorkspaceSnapshotBuildError(
        message: "Copy to Project is only available for global essentials."
      )
    }

    let markdown = try loadMarkdown(fileURL: item.fileURL)
    try saveMarkdown(
      workspaceURL: workspaceURL,
      itemID: item.id,
      markdown: markdown
    )
  }

  private func destinationFileURL(
    projectScopeURL: URL,
    itemID: String
  ) -> URL {
    projectScopeURL
      .appendingPathComponent("Packs/essentials")
      .appendingPathComponent("\(itemID).md")
  }
}

/// Injectable filesystem behavior for essentials markdown editing.
public struct WorkspaceEssentialManagerDependencies: Sendable {
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

  public static func live() -> WorkspaceEssentialManagerDependencies {
    WorkspaceEssentialManagerDependencies(
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
