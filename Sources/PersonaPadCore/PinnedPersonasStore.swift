import Foundation

public struct PinnedPersonasStore {
  /// Storage location: Application Support/PersonaPad/State/pins.json
  public static func defaultFileURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    PersonaPadStoragePaths.standard(homeDirectory: homeDirectory)
      .state
      .appendingPathComponent("pins.json")
  }

  public let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL = PinnedPersonasStore.defaultFileURL(), fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() -> [String] {
    guard fileManager.fileExists(atPath: fileURL.path),
          let data = try? Data(contentsOf: fileURL),
          let decoded = PinnedPersonasStore.decode(data) else {
      return []
    }
    return decoded.sorted()
  }

  public func save(_ pins: [String]) {
    let sorted = pins.sorted()
    guard let data = PinnedPersonasStore.encode(sorted) else { return }
    let folder = fileURL.deletingLastPathComponent()
    try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: [.atomic])
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
