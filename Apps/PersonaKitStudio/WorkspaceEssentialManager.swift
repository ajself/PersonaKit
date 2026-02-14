import Foundation
import PersonaKitCore

/// Essentials markdown editing contract used by `WorkspaceStore`.
protocol WorkspaceEssentialManaging: Sendable {
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
struct WorkspaceEssentialManager: WorkspaceEssentialManaging, Sendable {
  private let dependencies: WorkspaceEssentialManagerDependencies

  init(
    dependencies: WorkspaceEssentialManagerDependencies = .live()
  ) {
    self.dependencies = dependencies
  }

  func loadMarkdown(fileURL: URL) throws -> String {
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

  func saveMarkdown(
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

  func copyGlobalEssentialToProject(
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
struct WorkspaceEssentialManagerDependencies {
  let directoryExists: @Sendable (URL) -> Bool
  let createDirectory: @Sendable (URL) throws -> Void
  let readData: @Sendable (URL) throws -> Data
  let writeData: @Sendable (Data, URL) throws -> Void

  static func live() -> WorkspaceEssentialManagerDependencies {
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
