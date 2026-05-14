import Foundation

struct StudioRecentWorkspace: Equatable, Identifiable, Sendable {
  let path: String
  let bookmarkData: Data?

  init(
    path: String,
    bookmarkData: Data? = nil
  ) {
    self.path = path
    self.bookmarkData = bookmarkData
  }

  var id: String {
    path
  }

  var url: URL {
    URL(fileURLWithPath: path, isDirectory: true)
  }

  var displayName: String {
    let url = URL(fileURLWithPath: path)
    let lastPathComponent = url.lastPathComponent

    guard !lastPathComponent.isEmpty else {
      return path
    }

    return lastPathComponent
  }

  var detail: String {
    let url = URL(fileURLWithPath: path)
    let parentPath = url.deletingLastPathComponent().path

    guard parentPath != "." else {
      return path
    }

    return parentPath
  }
}

enum StudioRecentWorkspacesState {
  static let maximumCount = 6
  static let storageKey = "studio.recentWorkspaces.v1"

  static func workspaces(from storageValue: String) -> [StudioRecentWorkspace] {
    guard let data = storageValue.data(using: .utf8),
      let storedWorkspaces = storedWorkspaces(from: data)
    else {
      return []
    }

    return uniqueStandardizedWorkspaces(storedWorkspaces)
      .prefix(maximumCount)
      .map(\.workspace)
  }

  static func storageValue(
    adding workspaceURL: URL,
    bookmarkData: Data? = nil,
    to storageValue: String
  ) -> String {
    let existingWorkspaces = workspaces(from: storageValue).map(StoredWorkspace.init(workspace:))
    let newWorkspace = StoredWorkspace(
      path: normalizedDirectoryPath(workspaceURL.standardizedFileURL.path()),
      bookmarkData: bookmarkData?.base64EncodedString()
    )
    let workspaces = uniqueStandardizedWorkspaces([newWorkspace] + existingWorkspaces)
      .prefix(maximumCount)

    return encodedStorageValue(Array(workspaces))
  }

  static func storageValue(
    removing workspace: StudioRecentWorkspace,
    from storageValue: String
  ) -> String {
    let removedPath = normalizedDirectoryPath(
      URL(fileURLWithPath: workspace.path, isDirectory: true)
        .standardizedFileURL
        .path()
    )
    let workspaces = workspaces(from: storageValue)
      .map(StoredWorkspace.init(workspace:))
      .filter { $0.path != removedPath }

    return encodedStorageValue(workspaces)
  }

  static func securityScopedBookmarkData(for workspaceURL: URL) -> Data? {
    try? workspaceURL.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  private static func storedWorkspaces(from data: Data) -> [StoredWorkspace]? {
    if let workspaces = try? JSONDecoder().decode([StoredWorkspace].self, from: data) {
      return workspaces
    }

    guard let paths = try? JSONDecoder().decode([String].self, from: data) else {
      return nil
    }

    return paths.map {
      StoredWorkspace(path: $0, bookmarkData: nil)
    }
  }

  private static func uniqueStandardizedWorkspaces(_ workspaces: [StoredWorkspace]) -> [StoredWorkspace] {
    var result: [StoredWorkspace] = []

    for workspace in workspaces {
      let standardizedPath = normalizedDirectoryPath(
        URL(fileURLWithPath: workspace.path, isDirectory: true)
          .standardizedFileURL
          .path()
      )

      guard !standardizedPath.isEmpty else {
        continue
      }

      if let existingIndex = result.firstIndex(where: { $0.path == standardizedPath }) {
        if result[existingIndex].bookmarkData == nil,
          let bookmarkData = workspace.bookmarkData
        {
          result[existingIndex] = StoredWorkspace(
            path: standardizedPath,
            bookmarkData: bookmarkData
          )
        }

        continue
      }

      result.append(
        StoredWorkspace(
          path: standardizedPath,
          bookmarkData: workspace.bookmarkData
        )
      )
    }

    return result
  }

  private static func normalizedDirectoryPath(_ path: String) -> String {
    guard path.count > 1,
      path.hasSuffix("/")
    else {
      return path
    }

    return String(path.dropLast())
  }

  private static func encodedStorageValue(_ workspaces: [StoredWorkspace]) -> String {
    guard let data = try? JSONEncoder().encode(workspaces),
      let value = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }

    return value
  }
}

@MainActor
final class StudioRecentWorkspaceAccess {
  private var accessedURL: URL?

  func url(for workspace: StudioRecentWorkspace) -> URL {
    stop()

    guard let bookmarkData = workspace.bookmarkData else {
      return workspace.url
    }

    var isStale = false

    guard
      let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      .standardizedFileURL
    else {
      return workspace.url
    }

    if url.startAccessingSecurityScopedResource() {
      accessedURL = url
    }

    return url
  }

  func stop() {
    accessedURL?.stopAccessingSecurityScopedResource()
    accessedURL = nil
  }
}

private struct StoredWorkspace: Codable, Equatable {
  let path: String
  let bookmarkData: String?

  init(
    path: String,
    bookmarkData: String?
  ) {
    self.path = path
    self.bookmarkData = bookmarkData
  }

  init(workspace: StudioRecentWorkspace) {
    self.path = workspace.path
    self.bookmarkData = workspace.bookmarkData?.base64EncodedString()
  }

  var workspace: StudioRecentWorkspace {
    StudioRecentWorkspace(
      path: path,
      bookmarkData: bookmarkData.flatMap { Data(base64Encoded: $0) }
    )
  }
}
