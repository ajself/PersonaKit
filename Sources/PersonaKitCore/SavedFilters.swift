import Dependencies
import Foundation

/// A persisted sidebar filter configuration.
public struct SavedFilter: Codable, Sendable, Hashable, Identifiable {
  public let id: String
  public let name: String
  public let queryText: String
  public let selectedTags: [String]
  public let selectedSources: [String]
  public let groupingMode: String?

  /// Creates a saved filter record.
  public init(
    id: String,
    name: String,
    queryText: String,
    selectedTags: [String],
    selectedSources: [String],
    groupingMode: String?
  ) {
    self.id = id
    self.name = name
    self.queryText = queryText
    self.selectedTags = selectedTags
    self.selectedSources = selectedSources
    self.groupingMode = groupingMode
  }
}

/// File-backed store for saved filter definitions.
public struct SavedFiltersStore {
  /// Storage location: Application Support/PersonaKit/State/filters.json
  public static func defaultFileURL(
    homeDirectory: URL? = nil
  ) -> URL {
    PersonaKitStoragePaths.standard(homeDirectory: homeDirectory)
      .state
      .appendingPathComponent("filters.json")
  }

  public let fileURL: URL
  private let fileClient: FileClient

  /// Creates a saved filters store with an optional custom file client.
  public init(
    fileURL: URL = SavedFiltersStore.defaultFileURL(),
    fileClient: FileClient? = nil
  ) {
    @Dependency(\.fileClient) var resolvedFileClient
    self.fileURL = fileURL
    self.fileClient = fileClient ?? resolvedFileClient
  }

  /// Loads saved filters from disk, returning an empty array on failure.
  public func load() -> [SavedFilter] {
    guard fileClient.fileExists(fileURL),
      let data = try? fileClient.readData(fileURL),
      let decoded = SavedFiltersStore.decode(data)
    else {
      return []
    }
    return SavedFiltersStore.sorted(decoded)
  }

  /// Saves filters to disk using deterministic ordering.
  public func save(_ filters: [SavedFilter]) {
    let sorted = SavedFiltersStore.sorted(filters)
    guard let data = SavedFiltersStore.encode(sorted) else { return }
    let folder = fileURL.deletingLastPathComponent()
    try? fileClient.createDirectory(folder, true)
    try? fileClient.writeData(data, fileURL, [.atomic])
  }

  /// Encodes filters as pretty-printed, sorted JSON data.
  static func encode(_ filters: [SavedFilter]) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try? encoder.encode(filters)
  }

  /// Decodes filters from JSON data.
  static func decode(_ data: Data) -> [SavedFilter]? {
    let decoder = JSONDecoder()
    return try? decoder.decode([SavedFilter].self, from: data)
  }

  /// Sorts filters by name then id for stable ordering.
  static func sorted(_ filters: [SavedFilter]) -> [SavedFilter] {
    filters.sorted { lhs, rhs in
      if lhs.name != rhs.name { return lhs.name < rhs.name }
      return lhs.id < rhs.id
    }
  }
}
