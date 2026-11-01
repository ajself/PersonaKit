import CoreServices
import Foundation
import Synchronization

/// Streams batches of changed file URLs under a set of watched directories.
package protocol WorkspaceFileEventStreaming: Sendable {
  /// Starts watching `directories`; ending iteration of the returned stream stops watching.
  func changes(in directories: [URL]) -> AsyncStream<[URL]>
}

/// FSEvents-backed change stream.
///
/// Inside the App Sandbox, FSEvents only reports paths the app can already read, so this
/// relies on the security-scoped access Studio holds for the open workspace and the
/// entitlement-granted global library. It never requests access itself.
package struct FSEventsWorkspaceFileEventStream: WorkspaceFileEventStreaming {
  private let latency: TimeInterval

  package init(latency: TimeInterval = 0.1) {
    self.latency = latency
  }

  package func changes(in directories: [URL]) -> AsyncStream<[URL]> {
    let paths = directories.map { $0.standardizedFileURL.path }
    let latency = latency

    return AsyncStream { continuation in
      guard !paths.isEmpty else {
        continuation.finish()
        return
      }

      let watcher = FSEventStreamWatcher(continuation: continuation)

      guard watcher.start(paths: paths, latency: latency) else {
        continuation.finish()
        return
      }

      // The termination handler keeps the watcher alive for as long as the stream runs.
      continuation.onTermination = { _ in
        watcher.stop()
      }
    }
  }
}

private final class FSEventStreamWatcher: Sendable {
  private let continuation: AsyncStream<[URL]>.Continuation
  private let queue = DispatchQueue(label: "com.personakit.studio.workspace-file-events")
  private let stream = Mutex<FSEventStreamRef?>(nil)

  init(continuation: AsyncStream<[URL]>.Continuation) {
    self.continuation = continuation
  }

  func start(
    paths: [String],
    latency: TimeInterval
  ) -> Bool {
    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagUseCFTypes
        | kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagWatchRoot
    )

    // Create the stream inside the lock so the non-Sendable reference is only touched there.
    return stream.withLock { storedStream in
      var context = FSEventStreamContext(
        version: 0,
        info: Unmanaged.passUnretained(self).toOpaque(),
        retain: nil,
        release: nil,
        copyDescription: nil
      )

      guard
        let eventStream = FSEventStreamCreate(
          kCFAllocatorDefault,
          Self.callback,
          &context,
          paths as CFArray,
          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
          latency,
          flags
        )
      else {
        return false
      }

      FSEventStreamSetDispatchQueue(eventStream, queue)

      guard FSEventStreamStart(eventStream) else {
        FSEventStreamInvalidate(eventStream)
        FSEventStreamRelease(eventStream)
        return false
      }

      storedStream = eventStream
      return true
    }
  }

  func stop() {
    // Tear down on the event queue so an in-flight callback finishes before invalidation.
    queue.async {
      guard let eventStream = self.stream.withLock({ $0.take() }) else {
        return
      }

      FSEventStreamStop(eventStream)
      FSEventStreamInvalidate(eventStream)
      FSEventStreamRelease(eventStream)
    }
  }

  private func deliver(_ paths: [String]) {
    guard !paths.isEmpty else {
      return
    }

    continuation.yield(paths.map { URL(fileURLWithPath: $0) })
  }

  private static let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
    guard let info else {
      return
    }

    let watcher = Unmanaged<FSEventStreamWatcher>.fromOpaque(info).takeUnretainedValue()
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []

    watcher.deliver(paths)
  }
}
