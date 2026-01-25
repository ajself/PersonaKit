import Foundation

public struct SavedFilter: Codable, Sendable, Hashable, Identifiable {
  public let id: String
  public let name: String
  public let queryText: String
  public let selectedTags: [String]
  public let selectedSources: [String]
  public let groupingMode: String?

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

  public init(
    fileURL: URL = SavedFiltersStore.defaultFileURL(),
    fileClient: FileClient? = nil
  ) {
    self.fileURL = fileURL
    self.fileClient = fileClient ?? FileClientProvider().fileClient
  }

  public func load() -> [SavedFilter] {
    guard fileClient.fileExists(fileURL),
      let data = try? fileClient.readData(fileURL),
      let decoded = SavedFiltersStore.decode(data)
    else {
      return []
    }
    return SavedFiltersStore.sorted(decoded)
  }

  public func save(_ filters: [SavedFilter]) {
    let sorted = SavedFiltersStore.sorted(filters)
    guard let data = SavedFiltersStore.encode(sorted) else { return }
    let folder = fileURL.deletingLastPathComponent()
    try? fileClient.createDirectory(folder, true)
    try? fileClient.writeData(data, fileURL, [.atomic])
  }

  static func encode(_ filters: [SavedFilter]) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try? encoder.encode(filters)
  }

  static func decode(_ data: Data) -> [SavedFilter]? {
    let decoder = JSONDecoder()
    return try? decoder.decode([SavedFilter].self, from: data)
  }

  static func sorted(_ filters: [SavedFilter]) -> [SavedFilter] {
    filters.sorted { lhs, rhs in
      if lhs.name != rhs.name { return lhs.name < rhs.name }
      return lhs.id < rhs.id
    }
  }
}
