import Dependencies
import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("AppModel Reload Selection")
struct AppModelReloadSelectionTests {
  @Test("Reload preserves selection when persona exists")
  @MainActor
  func reloadPreservesSelectionWhenPersonaExists() throws {
    let model = makeModel()
    model.reloadAll()

    let ids = model.personaIndex.keys.sorted()
    let selected = try #require(ids.last)
    model.selectPersona(id: selected)

    model.reloadAll()
    #expect(model.composer.selectedPersonaID == selected)
  }

  @Test("Reload falls back to first persona when selection missing")
  @MainActor
  func reloadFallsBackWhenSelectionMissing() throws {
    let model = makeModel()
    model.reloadAll()

    model.composer.selectedPersonaID = "missing-persona-id"
    model.reloadAll()

    let expected = try #require(model.personaIndex.keys.sorted().first)
    #expect(model.composer.selectedPersonaID == expected)
  }

  @Test("Reload maps pack locations for directory and file packs")
  @MainActor
  func reloadMapsPackLocationsForDirectoryAndFilePacks() throws {
    let homeDirectory = URL(fileURLWithPath: "/tmp/personakit-tests-home", isDirectory: true)
    let packsRoot = PersonaKitStoragePaths.standard(homeDirectory: homeDirectory).packs
    let directoryPackRoot = packsRoot.appendingPathComponent("DirectoryPack", isDirectory: true)
    let directoryPackFile = directoryPackRoot.appendingPathComponent("Directory.pack.json")
    let filePackFile = packsRoot.appendingPathComponent("File.pack.json")

    let fileSystem = PackTestFileSystem()
    fileSystem.addDirectory(packsRoot)
    fileSystem.addDirectory(directoryPackRoot)
    fileSystem.setDirectoryContents(packsRoot, [directoryPackRoot, filePackFile])
    fileSystem.setDirectoryContents(directoryPackRoot, [directoryPackFile])
    fileSystem.write(
      packJSON(
        packID: "com.personakit.directory-pack",
        packName: "Directory Pack",
        personaID: "dir-persona",
        personaName: "Directory Persona"
      ),
      to: directoryPackFile
    )
    fileSystem.write(
      packJSON(
        packID: "com.personakit.file-pack",
        packName: "File Pack",
        personaID: "file-persona",
        personaName: "File Persona"
      ),
      to: filePackFile
    )

    let fileClient = fileClientForPackTests(
      fileSystem: fileSystem,
      homeDirectory: homeDirectory
    )
    let model = makeModel(fileClient: fileClient)
    withDependencies {
      $0.fileClient = fileClient
    } operation: {
      model.reloadAll()
    }

    let directoryLocation = try #require(model.packLocationsByPersonaID["dir-persona"])
    #expect(directoryLocation.packRoot == directoryPackRoot)
    #expect(directoryLocation.packFile == directoryPackFile)
    #expect(directoryLocation.isDirectoryPack == true)

    let fileLocation = try #require(model.packLocationsByPersonaID["file-persona"])
    #expect(fileLocation.packRoot == packsRoot)
    #expect(fileLocation.packFile == filePackFile)
    #expect(fileLocation.isDirectoryPack == false)
  }

  @MainActor
  private func makeModel(fileClient: FileClient = inMemoryFileClient()) -> AppModel {
    let filtersURL = URL(fileURLWithPath: "/tmp/personakit-tests/filters.json")
    let pinsURL = URL(fileURLWithPath: "/tmp/personakit-tests/pins.json")
    let savedFiltersStore = SavedFiltersStore(fileURL: filtersURL, fileClient: fileClient)
    let pinnedPersonasStore = PinnedPersonasStore(fileURL: pinsURL, fileClient: fileClient)
    let appClient = AppClient(
      selectPackURL: { nil },
      confirmRemovePack: { false },
      presentError: { _, _ in },
      openURL: { _ in },
      copyToClipboard: { _ in }
    )
    return withDependencies {
      $0.fileClient = fileClient
      $0.appClient = appClient
    } operation: {
      AppModel(savedFiltersStore: savedFiltersStore, pinnedPersonasStore: pinnedPersonasStore)
    }
  }
}

private func packJSON(
  packID: String,
  packName: String,
  personaID: String,
  personaName: String
) -> Data {
  let json = """
    {
      "schemaVersion": 1,
      "documentType": "personaPack",
      "pack": {
        "id": "\(packID)",
        "name": "\(packName)"
      },
      "personas": [
        {
          "id": "\(personaID)",
          "name": "\(personaName)",
          "system": "Test system prompt."
        }
      ]
    }
    """
  return Data(json.utf8)
}

private final class PackTestFileSystem: @unchecked Sendable {
  private var files: [URL: Data] = [:]
  private var directories: Set<URL> = []
  private var directoryContents: [URL: [URL]] = [:]
  private let lock = NSLock()

  func addDirectory(_ url: URL) {
    lock.lock()
    directories.insert(normalize(url))
    lock.unlock()
  }

  func setDirectoryContents(_ url: URL, _ contents: [URL]) {
    lock.lock()
    directoryContents[normalize(url)] = contents.map(normalize)
    lock.unlock()
  }

  func write(_ data: Data, to url: URL) {
    lock.lock()
    files[normalize(url)] = data
    lock.unlock()
  }

  func read(_ url: URL) throws -> Data {
    lock.lock()
    defer { lock.unlock() }
    guard let data = files[normalize(url)] else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return data
  }

  func exists(_ url: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let normalized = normalize(url)
    return files[normalized] != nil || directories.contains(normalized)
  }

  func contents(of url: URL) throws -> [URL] {
    lock.lock()
    defer { lock.unlock() }
    let normalized = normalize(url)
    guard directories.contains(normalized) else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return directoryContents[normalized] ?? []
  }

  func isDirectory(_ url: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return directories.contains(normalize(url))
  }

  func remove(_ url: URL) {
    lock.lock()
    let normalized = normalize(url)
    files.removeValue(forKey: normalized)
    directories.remove(normalized)
    directoryContents.removeValue(forKey: normalized)
    lock.unlock()
  }

  func move(_ source: URL, to destination: URL) {
    lock.lock()
    let normalizedSource = normalize(source)
    let normalizedDestination = normalize(destination)
    if let data = files[normalizedSource] {
      files.removeValue(forKey: normalizedSource)
      files[normalizedDestination] = data
    }
    lock.unlock()
  }

  func copy(_ source: URL, to destination: URL) {
    lock.lock()
    let normalizedSource = normalize(source)
    let normalizedDestination = normalize(destination)
    if let data = files[normalizedSource] {
      files[normalizedDestination] = data
    }
    lock.unlock()
  }

  private func normalize(_ url: URL) -> URL {
    url.standardizedFileURL
  }
}

private func fileClientForPackTests(
  fileSystem: PackTestFileSystem,
  homeDirectory: URL
) -> FileClient {
  FileClient(
    fileExists: { url in
      fileSystem.exists(url)
    },
    readData: { url in
      try fileSystem.read(url)
    },
    writeData: { data, url, _ in
      fileSystem.write(data, to: url)
    },
    createDirectory: { url, _ in
      fileSystem.addDirectory(url)
    },
    contentsOfDirectory: { url, _ in
      try fileSystem.contents(of: url)
    },
    enumerator: { _, _, _ in
      nil
    },
    removeItem: { url in
      fileSystem.remove(url)
    },
    moveItem: { source, destination in
      fileSystem.move(source, to: destination)
    },
    copyItem: { source, destination in
      fileSystem.copy(source, to: destination)
    },
    homeDirectory: {
      homeDirectory
    },
    currentDirectoryPath: {
      homeDirectory.path
    },
    isDirectory: { url in
      fileSystem.isDirectory(url)
    }
  )
}
