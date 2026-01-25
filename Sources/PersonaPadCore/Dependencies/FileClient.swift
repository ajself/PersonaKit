import Dependencies
import Foundation

public struct FileClient: Sendable {
  public var fileExists: @Sendable (URL) -> Bool
  public var readData: @Sendable (URL) throws -> Data
  public var writeData: @Sendable (Data, URL, Data.WritingOptions) throws -> Void
  public var createDirectory: @Sendable (URL, Bool) throws -> Void
  public var contentsOfDirectory: @Sendable (URL, [URLResourceKey]?) throws -> [URL]
  public var enumerator:
    @Sendable (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) -> FileManager
      .DirectoryEnumerator?
  public var removeItem: @Sendable (URL) throws -> Void
  public var moveItem: @Sendable (URL, URL) throws -> Void
  public var copyItem: @Sendable (URL, URL) throws -> Void
  public var homeDirectory: @Sendable () -> URL
  public var currentDirectoryPath: @Sendable () -> String
  public var isDirectory: @Sendable (URL) -> Bool

  public init(
    fileExists: @escaping @Sendable (URL) -> Bool,
    readData: @escaping @Sendable (URL) throws -> Data,
    writeData: @escaping @Sendable (Data, URL, Data.WritingOptions) throws -> Void,
    createDirectory: @escaping @Sendable (URL, Bool) throws -> Void,
    contentsOfDirectory: @escaping @Sendable (URL, [URLResourceKey]?) throws -> [URL],
    enumerator:
      @escaping @Sendable (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) ->
      FileManager.DirectoryEnumerator?,
    removeItem: @escaping @Sendable (URL) throws -> Void,
    moveItem: @escaping @Sendable (URL, URL) throws -> Void,
    copyItem: @escaping @Sendable (URL, URL) throws -> Void,
    homeDirectory: @escaping @Sendable () -> URL,
    currentDirectoryPath: @escaping @Sendable () -> String,
    isDirectory: @escaping @Sendable (URL) -> Bool
  ) {
    self.fileExists = fileExists
    self.readData = readData
    self.writeData = writeData
    self.createDirectory = createDirectory
    self.contentsOfDirectory = contentsOfDirectory
    self.enumerator = enumerator
    self.removeItem = removeItem
    self.moveItem = moveItem
    self.copyItem = copyItem
    self.homeDirectory = homeDirectory
    self.currentDirectoryPath = currentDirectoryPath
    self.isDirectory = isDirectory
  }
}

extension FileClient: DependencyKey {
  public static let liveValue = FileClient(
    fileExists: { url in
      FileManager.default.fileExists(atPath: url.path)
    },
    readData: { url in
      try Data(contentsOf: url)
    },
    writeData: { data, url, options in
      try data.write(to: url, options: options)
    },
    createDirectory: { url, withIntermediateDirectories in
      try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: withIntermediateDirectories)
    },
    contentsOfDirectory: { url, keys in
      try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)
    },
    enumerator: { url, keys, options in
      FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: options)
    },
    removeItem: { url in
      try FileManager.default.removeItem(at: url)
    },
    moveItem: { source, destination in
      try FileManager.default.moveItem(at: source, to: destination)
    },
    copyItem: { source, destination in
      try FileManager.default.copyItem(at: source, to: destination)
    },
    homeDirectory: {
      FileManager.default.homeDirectoryForCurrentUser
    },
    currentDirectoryPath: {
      FileManager.default.currentDirectoryPath
    },
    isDirectory: { url in
      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
  )

  public static var testValue: FileClient { liveValue }
  public static var previewValue: FileClient { liveValue }
}

extension DependencyValues {
  public var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}
