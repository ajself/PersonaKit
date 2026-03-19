import Foundation
import Testing

@testable import OrbitServerRuntime

struct OrbitArtifactStorageTests {
  @Test
  func filesystemStorageRoundTripsArtifactData() throws {
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("orbit-artifact-storage-roundtrip", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workspaceURL) }

    let storage = OrbitFilesystemArtifactStorage(rootDirectoryURL: workspaceURL)
    let request = OrbitArtifactPutRequest(
      namespace: "attachments",
      artifactID: "artifact-001.txt",
      mediaType: "text/plain",
      payload: Data("Orbit artifact payload".utf8),
      createdAt: Date(timeIntervalSince1970: 1_742_342_400)
    )

    let reference = try storage.put(request)
    let payload = try storage.get(reference: reference)

    #expect(reference.id == "artifact-001.txt")
    #expect(reference.namespace == "attachments")
    #expect(reference.mediaType == "text/plain")
    #expect(reference.byteCount == request.payload.count)
    #expect(payload == request.payload)
  }

  @Test
  func filesystemStorageDeletesArtifactsByReference() throws {
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("orbit-artifact-storage-delete", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workspaceURL) }

    let storage = OrbitFilesystemArtifactStorage(rootDirectoryURL: workspaceURL)
    let reference = try storage.put(
      OrbitArtifactPutRequest(
        namespace: "reports",
        artifactID: "retro.md",
        mediaType: "text/markdown",
        payload: Data("retro".utf8),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      )
    )

    try storage.delete(reference: reference)

    do {
      _ = try storage.get(reference: reference)
      Issue.record("Expected missing artifact error")
    } catch let error as OrbitArtifactStorageError {
      #expect(error == .artifactNotFound("retro.md"))
    }
  }

  @Test
  func filesystemStorageRejectsUnsafeNamespaces() throws {
    let storage = OrbitFilesystemArtifactStorage(
      rootDirectoryURL: FileManager.default.temporaryDirectory
    )

    do {
      _ = try storage.artifactFileURL(namespace: "../secrets", artifactID: "bad.txt")
      Issue.record("Expected invalid namespace error")
    } catch let error as OrbitArtifactStorageError {
      #expect(error == .invalidNamespace("../secrets"))
    }
  }
}
