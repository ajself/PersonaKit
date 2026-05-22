import ContextCore
import ContextWorkspaceCore
import Foundation

/// Session preview contract used by `WorkspaceStore` for preview and export actions.
public protocol WorkspaceSessionPreviewManaging: Sendable {
  func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String

  func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws
}

/// Filesystem-backed preview manager using `ContextCore` resolver/exporter logic.
public struct WorkspaceSessionPreviewManager: WorkspaceSessionPreviewManaging, Sendable {
  private let sessionManager: any WorkspaceSessionManaging
  private let previewBuilder: any WorkspaceSessionPreviewBuilding
  private let dependencies: WorkspaceSessionPreviewManagerDependencies

  public init(
    sessionManager: any WorkspaceSessionManaging,
    previewBuilder: any WorkspaceSessionPreviewBuilding = WorkspaceSessionPreviewBuilder(),
    dependencies: WorkspaceSessionPreviewManagerDependencies = .live()
  ) {
    self.sessionManager = sessionManager
    self.previewBuilder = previewBuilder
    self.dependencies = dependencies
  }

  public func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    let projectScopeURL = try resolveProjectScopeURL(workspaceURL)
    let globalScopeURL = dependencies.defaultGlobalScopeURL()
    let draft = try sessionManager.loadDraft(fileURL: session.fileURL)

    return try previewBuilder.build(
      projectScopeURL: projectScopeURL,
      globalScopeURL: globalScopeURL,
      sessionId: session.id,
      personaId: draft.personaId,
      directiveId: draft.directiveId,
      kitOverrides: draft.kitOverrides
    )
  }

  public func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {
    do {
      try dependencies.createDirectory(destinationURL.deletingLastPathComponent())
      try dependencies.writeData(Data(preview.utf8), destinationURL)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to export preview: \(error.localizedDescription)"
      )
    }
  }

  private func resolveProjectScopeURL(_ workspaceURL: URL) throws -> URL {
    do {
      return try WorkspaceProjectScopeResolver.resolveProjectScopeURL(
        workspaceURL,
        directoryExists: dependencies.directoryExists,
        fileExists: dependencies.fileExists
      )
    } catch let error as MissingPersonaKitDirectoryError {
      throw WorkspaceSnapshotBuildError(
        message: "Missing PersonaKit directory at \(error.projectScopeURL.path())."
      )
    }
  }
}

/// Injectable filesystem/global-scope dependencies for preview generation and export.
public struct WorkspaceSessionPreviewManagerDependencies: Sendable {
  public let directoryExists: @Sendable (URL) -> Bool
  public let fileExists: @Sendable (URL) -> Bool
  public let defaultGlobalScopeURL: @Sendable () -> URL?
  public let createDirectory: @Sendable (URL) throws -> Void
  public let writeData: @Sendable (Data, URL) throws -> Void

  public init(
    directoryExists: @escaping @Sendable (URL) -> Bool,
    fileExists: @escaping @Sendable (URL) -> Bool = { _ in false },
    defaultGlobalScopeURL: @escaping @Sendable () -> URL?,
    createDirectory: @escaping @Sendable (URL) throws -> Void,
    writeData: @escaping @Sendable (Data, URL) throws -> Void
  ) {
    self.directoryExists = directoryExists
    self.fileExists = fileExists
    self.defaultGlobalScopeURL = defaultGlobalScopeURL
    self.createDirectory = createDirectory
    self.writeData = writeData
  }

  public static func live() -> WorkspaceSessionPreviewManagerDependencies {
    WorkspaceSessionPreviewManagerDependencies(
      directoryExists: { url in
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      fileExists: { url in
        FileManager.default.fileExists(atPath: url.path())
      },
      defaultGlobalScopeURL: {
        let fileManager = FileManager.default
        let candidate = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".personakit")
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
          isDirectory.boolValue
        else {
          return nil
        }

        return candidate.standardizedFileURL
      },
      createDirectory: { url in
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
      },
      writeData: { data, url in
        try data.write(to: url, options: [.atomic])
      }
    )
  }
}
