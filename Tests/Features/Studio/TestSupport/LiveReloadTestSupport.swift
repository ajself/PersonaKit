import Foundation
import StudioFoundation
import Synchronization

/// A clock that only moves when a test advances it, so debounce timing is deterministic.
final class ManualTestClock: Clock, Sendable {
  struct Instant: InstantProtocol {
    var offset: Duration

    func advanced(by duration: Duration) -> Instant {
      Instant(offset: offset + duration)
    }

    func duration(to other: Instant) -> Duration {
      other.offset - offset
    }

    static func < (lhs: Instant, rhs: Instant) -> Bool {
      lhs.offset < rhs.offset
    }
  }

  private struct Sleeper: Sendable {
    let deadline: Instant
    let continuation: CheckedContinuation<Void, Never>
  }

  private struct State: Sendable {
    var now = Instant(offset: .zero)
    var nextSleeperID: UInt64 = 0
    var sleepers: [UInt64: Sleeper] = [:]
    var cancelledSleeperIDs: Set<UInt64> = []
  }

  private let state = Mutex(State())

  var now: Instant {
    state.withLock { $0.now }
  }

  var minimumResolution: Duration {
    .zero
  }

  /// Number of tasks currently suspended in `sleep(until:tolerance:)`.
  var sleeperCount: Int {
    state.withLock { $0.sleepers.count }
  }

  /// Deadlines of the suspended sleepers, as offsets from the clock's start, sorted.
  var sleeperDeadlines: [Duration] {
    state.withLock { $0.sleepers.values.map(\.deadline.offset).sorted() }
  }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    let sleeperID = state.withLock { state in
      state.nextSleeperID += 1
      return state.nextSleeperID
    }

    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        let resumesImmediately = state.withLock { state in
          if state.cancelledSleeperIDs.remove(sleeperID) != nil || deadline <= state.now {
            return true
          }

          state.sleepers[sleeperID] = Sleeper(deadline: deadline, continuation: continuation)
          return false
        }

        if resumesImmediately {
          continuation.resume()
        }
      }
    } onCancel: {
      let sleeper = state.withLock { state in
        guard let sleeper = state.sleepers.removeValue(forKey: sleeperID) else {
          state.cancelledSleeperIDs.insert(sleeperID)
          return Sleeper?.none
        }

        return sleeper
      }

      sleeper?.continuation.resume()
    }

    try Task.checkCancellation()
  }

  /// Moves time forward and wakes every sleeper whose deadline has passed.
  func advance(by duration: Duration) {
    let dueSleepers = state.withLock { state in
      state.now = state.now.advanced(by: duration)

      let dueIDs = state.sleepers.filter { $0.value.deadline <= state.now }.map(\.key)

      return dueIDs.compactMap { state.sleepers.removeValue(forKey: $0) }
    }

    for sleeper in dueSleepers {
      sleeper.continuation.resume()
    }
  }
}

/// File-event source a test drives by hand instead of FSEvents.
final class StubFileEventSource: WorkspaceFileEventStreaming, Sendable {
  private struct State: Sendable {
    var continuations: [AsyncStream<[URL]>.Continuation] = []
    var watchedDirectories: [[URL]] = []
    var terminationCount = 0
  }

  private let state = Mutex(State())

  /// Every directory list passed to `changes(in:)`, oldest first.
  var watchedDirectories: [[URL]] {
    state.withLock { $0.watchedDirectories }
  }

  /// How many watch streams have ended.
  var terminationCount: Int {
    state.withLock { $0.terminationCount }
  }

  func changes(in directories: [URL]) -> AsyncStream<[URL]> {
    let (stream, continuation) = AsyncStream.makeStream(of: [URL].self)

    continuation.onTermination = { [weak self] _ in
      self?.state.withLock { $0.terminationCount += 1 }
    }

    state.withLock { state in
      state.continuations.append(continuation)
      state.watchedDirectories.append(directories)
    }

    return stream
  }

  /// Emits a change batch on the most recent watch stream.
  func emit(_ changedFileURLs: [URL]) {
    let continuation = state.withLock { $0.continuations.last }

    continuation?.yield(changedFileURLs)
  }
}

/// Thread-safe text a stub can read while a test changes it, standing in for a file on disk.
final class MutableTextState: Sendable {
  private let state: Mutex<String>

  init(_ value: String) {
    state = Mutex(value)
  }

  var value: String {
    get {
      state.withLock { $0 }
    }

    set {
      state.withLock { $0 = newValue }
    }
  }
}

/// Thread-safe call counter for stubs.
final class CallCounter: Sendable {
  private let state = Mutex(0)

  var count: Int {
    state.withLock { $0 }
  }

  func increment() {
    state.withLock { $0 += 1 }
  }
}
