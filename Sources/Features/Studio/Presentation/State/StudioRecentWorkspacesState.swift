import Foundation
import Observation
import StudioFoundation

protocol StudioRecentWorkspaceBookmarking {
  func bookmarkData(for workspaceURL: URL) -> Data?
}

protocol StudioRecentWorkspaceSecurityScopeResolving {
  func resolveURL(from bookmarkData: Data) -> (url: URL, isStale: Bool)?
  func startAccessing(_ url: URL) -> Bool
  func stopAccessing(_ url: URL)
}

struct StudioRecentWorkspaceBookmarkClient: StudioRecentWorkspaceBookmarking {
  func bookmarkData(for workspaceURL: URL) -> Data? {
    try? workspaceURL.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }
}

struct StudioRecentWorkspaceSecurityScopeClient: StudioRecentWorkspaceSecurityScopeResolving {
  func resolveURL(from bookmarkData: Data) -> (url: URL, isStale: Bool)? {
    var isStale = false

    guard
      let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    else {
      return nil
    }

    return (url.standardizedFileURL, isStale)
  }

  func startAccessing(_ url: URL) -> Bool {
    url.startAccessingSecurityScopedResource()
  }

  func stopAccessing(_ url: URL) {
    url.stopAccessingSecurityScopedResource()
  }
}

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
    securityScopedBookmarkData(
      for: workspaceURL,
      bookmarkClient: StudioRecentWorkspaceBookmarkClient()
    )
  }

  static func securityScopedBookmarkData(
    for workspaceURL: URL,
    bookmarkClient: any StudioRecentWorkspaceBookmarking
  ) -> Data? {
    bookmarkClient.bookmarkData(for: workspaceURL)
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
protocol StudioRecentWorkspaceAccessing: AnyObject {
  /// Starts access to a recent workspace's folder and returns the entry to record: its resolved path, and a fresh
  /// bookmark when the saved one is stale.
  func access(_ workspace: StudioRecentWorkspace) -> StudioRecentWorkspace
  func stop()
}

final class StudioRecentWorkspaceAccess: StudioRecentWorkspaceAccessing {
  private let securityScopeClient: any StudioRecentWorkspaceSecurityScopeResolving
  private let bookmarkClient: any StudioRecentWorkspaceBookmarking
  private var accessedURL: URL?

  init(
    securityScopeClient: any StudioRecentWorkspaceSecurityScopeResolving =
      StudioRecentWorkspaceSecurityScopeClient(),
    bookmarkClient: any StudioRecentWorkspaceBookmarking = StudioRecentWorkspaceBookmarkClient()
  ) {
    self.securityScopeClient = securityScopeClient
    self.bookmarkClient = bookmarkClient
  }

  func access(_ workspace: StudioRecentWorkspace) -> StudioRecentWorkspace {
    stop()

    guard
      let bookmarkData = workspace.bookmarkData,
      let resolved = securityScopeClient.resolveURL(from: bookmarkData)
    else {
      return workspace
    }

    guard securityScopeClient.startAccessing(resolved.url) else {
      return StudioRecentWorkspace(path: resolved.url.path(percentEncoded: false), bookmarkData: bookmarkData)
    }

    accessedURL = resolved.url

    // A stale bookmark still opens the folder for now, so replace it while access is held, before it stops working.
    let currentBookmarkData =
      resolved.isStale
      ? bookmarkClient.bookmarkData(for: resolved.url) ?? bookmarkData
      : bookmarkData

    return StudioRecentWorkspace(path: resolved.url.path(percentEncoded: false), bookmarkData: currentBookmarkData)
  }

  func stop() {
    if let accessedURL {
      securityScopeClient.stopAccessing(accessedURL)
    }

    accessedURL = nil
  }
}

@Observable
@MainActor
final class StudioRecentWorkspacesFeatureModel {
  @ObservationIgnored private let bookmarkDataProvider: (URL) -> Data?
  @ObservationIgnored private let recentWorkspaceAccess: any StudioRecentWorkspaceAccessing
  @ObservationIgnored private let storage: any StudioRecentWorkspacesPersisting
  private var storageValue: String

  init(
    storage: any StudioRecentWorkspacesPersisting = StudioRecentWorkspacesUserDefaultsStorage(
      userDefaults: StudioLaunchConfiguration.userDefaults()
    ),
    recentWorkspaceAccess: any StudioRecentWorkspaceAccessing = StudioRecentWorkspaceAccess(),
    bookmarkDataProvider: @escaping (URL) -> Data? =
      StudioRecentWorkspacesState.securityScopedBookmarkData
  ) {
    self.bookmarkDataProvider = bookmarkDataProvider
    self.recentWorkspaceAccess = recentWorkspaceAccess
    self.storage = storage
    self.storageValue = storage.storageValue
  }

  var workspaces: [StudioRecentWorkspace] {
    StudioRecentWorkspacesState.workspaces(from: storageValue)
  }

  @discardableResult
  func recordWorkspace(
    at workspaceURL: URL,
    bookmarkData: Data? = nil
  ) -> Bool {
    updateStorageValue(
      StudioRecentWorkspacesState.storageValue(
        adding: workspaceURL,
        bookmarkData: bookmarkData,
        to: storageValue
      )
    )
  }

  @discardableResult
  func recordCurrentWorkspaceIfLoaded(
    workspaceURL: URL?
  ) -> Bool {
    guard let workspaceURL else {
      return false
    }

    return recordWorkspace(
      at: workspaceURL,
      bookmarkData: bookmarkDataProvider(workspaceURL)
    )
  }

  @discardableResult
  func remove(_ workspace: StudioRecentWorkspace) -> Bool {
    updateStorageValue(
      StudioRecentWorkspacesState.storageValue(
        removing: workspace,
        from: storageValue
      )
    )
  }

  func access(_ workspace: StudioRecentWorkspace) -> StudioRecentWorkspace {
    recentWorkspaceAccess.access(workspace)
  }

  func stopAccess() {
    recentWorkspaceAccess.stop()
  }

  private func updateStorageValue(_ newValue: String) -> Bool {
    guard newValue != storageValue else {
      return false
    }

    storageValue = newValue
    storage.storageValue = newValue
    return true
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
