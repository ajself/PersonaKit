import Dependencies
import Foundation

/// File-backed store for pinned persona identifiers.
public struct PinnedPersonasStore {
  /// Storage location: Application Support/PersonaKit/State/pins.json
  public static func defaultFileURL(
    homeDirectory: URL? = nil
  ) -> URL {
    PersonaKitStoragePaths.standard(homeDirectory: homeDirectory)
      .state
      .appendingPathComponent("pins.json")
  }

  public let fileURL: URL
  private let fileClient: FileClient

  /// Creates a pinned personas store with an optional custom file client.
  public init(
    fileURL: URL = PinnedPersonasStore.defaultFileURL(),
    fileClient: FileClient? = nil
  ) {
    self.fileURL = fileURL
    self.fileClient = fileClient ?? DependencyValues.current.fileClient
  }

  /// Loads pinned persona ids from disk, returning an empty array on failure.
  public func load() -> [String] {
    guard fileClient.fileExists(fileURL),
      let data = try? fileClient.readData(fileURL),
      let decoded = PinnedPersonasStore.decode(data)
    else {
      return []
    }
    return decoded.sorted()
  }

  /// Saves pinned persona ids to disk using deterministic ordering.
  public func save(_ pins: [String]) {
    let sorted = pins.sorted()
    guard let data = PinnedPersonasStore.encode(sorted) else { return }
    let folder = fileURL.deletingLastPathComponent()
    try? fileClient.createDirectory(folder, true)
    try? fileClient.writeData(data, fileURL, [.atomic])
  }

  /// Encodes pins as pretty-printed, sorted JSON data.
  static func encode(_ pins: [String]) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try? encoder.encode(pins)
  }

  /// Decodes pins from JSON data.
  static func decode(_ data: Data) -> [String]? {
    let decoder = JSONDecoder()
    return try? decoder.decode([String].self, from: data)
  }
}
