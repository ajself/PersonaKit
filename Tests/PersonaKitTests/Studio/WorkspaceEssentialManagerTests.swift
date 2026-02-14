import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitStudio

struct WorkspaceEssentialManagerTests {
  @Test
  func loadMarkdownWrapsReadFailures() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: makeDependencies(
        readData: { _ in
          throw WorkspaceEssentialManagerTestError.syntheticReadFailure
        }
      )
    )

    do {
      _ = try manager.loadMarkdown(fileURL: URL(fileURLWithPath: "/missing.md"))
      Issue.record("Expected loadMarkdown to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Failed to load markdown"))
    }
  }

  @Test
  func saveMarkdownFailsWhenProjectScopeIsMissing() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: makeDependencies(
        directoryExists: { _ in false }
      )
    )

    do {
      try manager.saveMarkdown(
        workspaceURL: URL(fileURLWithPath: "/Workspace"),
        itemID: "essential-a",
        markdown: "# Essential A\n"
      )
      Issue.record("Expected saveMarkdown to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Missing PersonaKit directory"))
    }
  }

  @Test
  func saveMarkdownWrapsWriteFailures() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: makeDependencies(
        writeData: { _, _ in
          throw WorkspaceEssentialManagerTestError.syntheticWriteFailure
        }
      )
    )

    do {
      try manager.saveMarkdown(
        workspaceURL: URL(fileURLWithPath: "/Workspace"),
        itemID: "essential-a",
        markdown: "# Essential A\n"
      )
      Issue.record("Expected saveMarkdown to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Failed to save markdown"))
    }
  }

  @Test
  func copyGlobalEssentialToProjectRejectsNonGlobalItems() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: makeDependencies()
    )

    do {
      try manager.copyGlobalEssentialToProject(
        workspaceURL: URL(fileURLWithPath: "/Workspace"),
        item: WorkspaceListItem(
          id: "essential-a",
          displayName: "Essential A",
          fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/essentials/essential-a.md"),
          sourceScope: .project
        )
      )
      Issue.record("Expected copyGlobalEssentialToProject to throw.")
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("only available for global essentials"))
    }
  }

  @Test
  func saveMarkdownWritesToProjectScopeEssentialPath() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    try manager.saveMarkdown(
      workspaceURL: workspaceURL,
      itemID: "essential-a",
      markdown: "# Essential A\n"
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/essentials/essential-a.md")
    let writtenData = try Data(contentsOf: destinationURL)

    #expect(String(data: writtenData, encoding: .utf8) == "# Essential A\n")
  }

  @Test
  func saveMarkdownRejectsUnsafeItemID() throws {
    let manager = WorkspaceEssentialManager(
      dependencies: .live()
    )
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    do {
      try manager.saveMarkdown(
        workspaceURL: workspaceURL,
        itemID: "../essential-a",
        markdown: "# Essential A\n"
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("is not valid"))
    }
  }

  @Test
  func copyGlobalEssentialToProjectWritesProjectFile() throws {
    let workspaceURL = try makeTempDirectory()
    let packsURL = workspaceURL.appendingPathComponent(".personakit/Packs")
    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    let globalRootURL = try makeTempDirectory()
    let globalFileURL =
      globalRootURL
      .appendingPathComponent("Packs/essentials/essential-a.md")
    try FileManager.default.createDirectory(
      at: globalFileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("# Essential A\n".utf8).write(to: globalFileURL, options: [.atomic])

    let manager = WorkspaceEssentialManager(
      dependencies: .live()
    )

    try manager.copyGlobalEssentialToProject(
      workspaceURL: workspaceURL,
      item: WorkspaceListItem(
        id: "essential-a",
        displayName: "Essential A",
        fileURL: globalFileURL,
        sourceScope: .global
      )
    )

    let destinationURL =
      workspaceURL
      .appendingPathComponent(".personakit/Packs/essentials/essential-a.md")
    #expect(FileManager.default.fileExists(atPath: destinationURL.path()))
  }
}

private enum WorkspaceEssentialManagerTestError: LocalizedError {
  case syntheticReadFailure
  case syntheticWriteFailure

  var errorDescription: String? {
    switch self {
    case .syntheticReadFailure:
      return "synthetic read failure"
    case .syntheticWriteFailure:
      return "synthetic write failure"
    }
  }
}

private func makeDependencies(
  directoryExists: @escaping @Sendable (URL) -> Bool = { _ in true },
  createDirectory: @escaping @Sendable (URL) throws -> Void = { _ in },
  readData: @escaping @Sendable (URL) throws -> Data = { _ in Data("# Default\n".utf8) },
  writeData: @escaping @Sendable (Data, URL) throws -> Void = { _, _ in }
) -> WorkspaceEssentialManagerDependencies {
  WorkspaceEssentialManagerDependencies(
    directoryExists: directoryExists,
    createDirectory: createDirectory,
    readData: readData,
    writeData: writeData
  )
}
