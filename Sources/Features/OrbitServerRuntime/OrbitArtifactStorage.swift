import Foundation

public struct OrbitArtifactReference: Equatable, Sendable {
  public let id: String
  public let namespace: String
  public let mediaType: String
  public let byteCount: Int
  public let createdAt: Date

  public init(
    id: String,
    namespace: String,
    mediaType: String,
    byteCount: Int,
    createdAt: Date
  ) {
    self.id = id
    self.namespace = namespace
    self.mediaType = mediaType
    self.byteCount = byteCount
    self.createdAt = createdAt
  }
}

public struct OrbitArtifactPutRequest: Equatable, Sendable {
  public let namespace: String
  public let artifactID: String
  public let mediaType: String
  public let payload: Data
  public let createdAt: Date

  public init(
    namespace: String,
    artifactID: String,
    mediaType: String,
    payload: Data,
    createdAt: Date
  ) {
    self.namespace = namespace
    self.artifactID = artifactID
    self.mediaType = mediaType
    self.payload = payload
    self.createdAt = createdAt
  }
}

public protocol OrbitArtifactStorage: Sendable {
  func put(_ request: OrbitArtifactPutRequest) throws -> OrbitArtifactReference
  func get(reference: OrbitArtifactReference) throws -> Data
  func delete(reference: OrbitArtifactReference) throws
}

public enum OrbitArtifactStorageError: Error, Equatable {
  case invalidNamespace(String)
  case artifactNotFound(String)
}

public struct OrbitFilesystemArtifactStorage: OrbitArtifactStorage, Sendable {
  public let rootDirectoryURL: URL

  public init(
    rootDirectoryURL: URL
  ) {
    self.rootDirectoryURL = rootDirectoryURL.standardizedFileURL
  }

  public func put(
    _ request: OrbitArtifactPutRequest
  ) throws -> OrbitArtifactReference {
    let fileURL = try artifactFileURL(
      namespace: request.namespace,
      artifactID: request.artifactID
    )
    let namespaceDirectoryURL = fileURL.deletingLastPathComponent()
    let fileManager = FileManager.default

    try fileManager.createDirectory(
      at: namespaceDirectoryURL,
      withIntermediateDirectories: true
    )
    try request.payload.write(to: fileURL, options: [.atomic])

    return OrbitArtifactReference(
      id: request.artifactID,
      namespace: request.namespace,
      mediaType: request.mediaType,
      byteCount: request.payload.count,
      createdAt: request.createdAt
    )
  }

  public func get(
    reference: OrbitArtifactReference
  ) throws -> Data {
    let fileURL = try artifactFileURL(
      namespace: reference.namespace,
      artifactID: reference.id
    )
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      throw OrbitArtifactStorageError.artifactNotFound(reference.id)
    }

    return try Data(contentsOf: fileURL)
  }

  public func delete(
    reference: OrbitArtifactReference
  ) throws {
    let fileURL = try artifactFileURL(
      namespace: reference.namespace,
      artifactID: reference.id
    )
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      throw OrbitArtifactStorageError.artifactNotFound(reference.id)
    }

    try fileManager.removeItem(at: fileURL)
  }

  public func artifactFileURL(
    namespace: String,
    artifactID: String
  ) throws -> URL {
    guard isSafeNamespace(namespace) else {
      throw OrbitArtifactStorageError.invalidNamespace(namespace)
    }

    return rootDirectoryURL
      .appendingPathComponent(namespace, isDirectory: true)
      .appendingPathComponent(artifactID, isDirectory: false)
  }

  private func isSafeNamespace(
    _ namespace: String
  ) -> Bool {
    !namespace.isEmpty
      && !namespace.contains("..")
      && namespace.split(separator: "/").allSatisfy { segment in
        !segment.isEmpty && segment.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
      }
  }
}
