import Dependencies
import Foundation
import PersonaPadCore
import Testing

@testable import PersonaPadApp

@Suite("Pinned View Toggle")
struct PinnedViewToggleTests {
  @Test("Pinned view toggles on and off")
  @MainActor
  func pinnedViewTogglesOnAndOff() {
    let store = makeStore()

    #expect(store.state.isPinnedViewActive == false)

    store.send(.setPinnedViewActive)
    #expect(store.state.isPinnedViewActive == true)

    store.send(.setPinnedViewActive)
    #expect(store.state.isPinnedViewActive == false)
  }

  @Test("Unpinning last persona disables pinned view")
  @MainActor
  func unpinningLastPersonaDisablesPinnedView() {
    let store = makeStore()
    store.send(.togglePinnedPersona(id: "persona-1"))
    store.send(.setPinnedViewActive)

    #expect(store.state.isPinnedViewActive == true)

    store.send(.togglePinnedPersona(id: "persona-1"))
    #expect(store.state.pinnedPersonaIDs.isEmpty)
    #expect(store.state.isPinnedViewActive == false)
  }

  @MainActor
  private func makeStore() -> AppStore {
    withDependencies {
      $0.fileClient = inMemoryFileClient()
    } operation: {
      AppStore()
    }
  }
}

private final class InMemoryFileStore: @unchecked Sendable {
  private var storage: [URL: Data] = [:]
  private let lock = NSLock()

  func exists(_ url: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return storage[url] != nil
  }

  func read(_ url: URL) throws -> Data {
    lock.lock()
    defer { lock.unlock() }
    guard let data = storage[url] else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return data
  }

  func write(_ data: Data, to url: URL) {
    lock.lock()
    storage[url] = data
    lock.unlock()
  }

  func remove(_ url: URL) {
    lock.lock()
    storage.removeValue(forKey: url)
    lock.unlock()
  }
}

private func inMemoryFileClient() -> FileClient {
  let store = InMemoryFileStore()
  return FileClient(
    fileExists: { url in
      store.exists(url)
    },
    readData: { url in
      try store.read(url)
    },
    writeData: { data, url, _ in
      store.write(data, to: url)
    },
    createDirectory: { _, _ in },
    contentsOfDirectory: { _, _ in
      []
    },
    enumerator: { _, _, _ in
      nil
    },
    removeItem: { url in
      store.remove(url)
    },
    moveItem: { source, destination in
      if let data = try? store.read(source) {
        store.remove(source)
        store.write(data, to: destination)
      }
    },
    copyItem: { source, destination in
      if let data = try? store.read(source) {
        store.write(data, to: destination)
      }
    },
    homeDirectory: {
      URL(fileURLWithPath: "/tmp/personapad-tests", isDirectory: true)
    },
    currentDirectoryPath: {
      "/tmp"
    },
    isDirectory: { _ in
      false
    }
  )
}
