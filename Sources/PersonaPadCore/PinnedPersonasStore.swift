import Foundation

public struct PinnedPersonasStore {
  /// Storage location: Application Support/PersonaPad/State/pins.json
  public static func defaultFileURL(
    homeDirectory: URL? = nil
  ) -> URL {
    PersonaPadStoragePaths.standard(homeDirectory: homeDirectory)
      .state
      .appendingPathComponent("pins.json")
  }

  public let fileURL: URL
  private let fileClient: FileClient

  public init(
    fileURL: URL = PinnedPersonasStore.defaultFileURL(),
    fileClient: FileClient? = nil
  ) {
    self.fileURL = fileURL
    self.fileClient = fileClient ?? FileClientProvider().fileClient
  }

  public func load() -> [String] {
    guard fileClient.fileExists(fileURL),
      let data = try? fileClient.readData(fileURL),
      let decoded = PinnedPersonasStore.decode(data)
    else {
      return []
    }
    return decoded.sorted()
  }

  public func save(_ pins: [String]) {
    let sorted = pins.sorted()
    guard let data = PinnedPersonasStore.encode(sorted) else { return }
    let folder = fileURL.deletingLastPathComponent()
    try? fileClient.createDirectory(folder, true)
    try? fileClient.writeData(data, fileURL, [.atomic])
  }

  static func encode(_ pins: [String]) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try? encoder.encode(pins)
  }

  static func decode(_ data: Data) -> [String]? {
    let decoder = JSONDecoder()
    return try? decoder.decode([String].self, from: data)
  }
}
