import Foundation
import OrbitServerRuntime

enum OrbitServerBackedRoomPersistentTransportResult: Equatable {
  case unavailable
  case degradedToPolling
  case finished
}

struct OrbitServerBackedRoomTransportRetryState: Equatable {
  private(set) var persistentTransportAvailable = true
  private(set) var pollsSincePersistentTransportFallback =
    OrbitServerBackedRoomTransportPolicy.pollsBeforePersistentRetry

  var shouldAttemptPersistentTransport: Bool {
    persistentTransportAvailable
      && pollsSincePersistentTransportFallback
        >= OrbitServerBackedRoomTransportPolicy.pollsBeforePersistentRetry
  }

  mutating func recordPersistentTransportResult(
    _ result: OrbitServerBackedRoomPersistentTransportResult
  ) {
    switch result {
    case .unavailable:
      persistentTransportAvailable = false
    case .degradedToPolling:
      pollsSincePersistentTransportFallback = 0
    case .finished:
      pollsSincePersistentTransportFallback =
        OrbitServerBackedRoomTransportPolicy.pollsBeforePersistentRetry
    }
  }

  mutating func recordPollingCycle() {
    guard persistentTransportAvailable else {
      return
    }

    guard
      pollsSincePersistentTransportFallback
        < OrbitServerBackedRoomTransportPolicy.pollsBeforePersistentRetry
    else {
      return
    }

    pollsSincePersistentTransportFallback += 1
  }
}

enum OrbitServerBackedRoomTransportPolicy {
  static var pollsBeforePersistentRetry: Int {
    3
  }

  static func shouldFallBackToPolling(
    after error: Error
  ) -> Bool {
    !(error is CancellationError)
  }

  static func fallbackMessage(
    after error: Error
  ) -> String {
    "Persistent Orbit transport disconnected; falling back to HTTP polling: \(error.localizedDescription)"
  }
}

enum OrbitWorkspacePersistenceError: LocalizedError {
  case noWorkspaceSelected

  var errorDescription: String? {
    switch self {
    case .noWorkspaceSelected:
      return "Open a workspace before sending Orbit messages."
    }
  }
}

extension OrbitPanelView {
  var serverBackedRoomScope: OrbitPhase1RealtimeSubscriptionScope {
    OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )
  }

  var orbitPersistence: OrbitWorkspacePersistence {
    OrbitWorkspacePersistence()
  }

  var serverBackedRoomPollInterval: Duration {
    .seconds(2)
  }

  func loadConfiguredOrbitRoom() {
    guard let serverBackedRoomClient else {
      loadOrbitWorkspace()
      return
    }

    Task {
      await loadServerBackedOrbitRoom(using: serverBackedRoomClient)
    }
  }

  func persistOrbitWorkspace(
    _ workspace: OrbitWorkspace
  ) throws {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      throw OrbitWorkspacePersistenceError.noWorkspaceSelected
    }

    try orbitPersistence.persist(workspace, to: workspaceURL)
  }

  func orbitDirectoryURL(
    for workspaceURL: URL
  ) -> URL {
    orbitPersistence.directoryURL(for: workspaceURL)
  }

  func orbitWorkspaceFileURL(
    for workspaceURL: URL
  ) -> URL {
    orbitPersistence.fileURL(for: workspaceURL)
  }

  func loadOrbitWorkspace() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      orbitWorkspace = .defaultWorkspace
      persistenceMessage = "Open a workspace to persist Orbit runtime data."
      persistenceIsError = false
      return
    }

    do {
      guard let decodedWorkspace = try orbitPersistence.loadWorkspace(from: workspaceURL) else {
        orbitWorkspace = .defaultWorkspace
        persistOrbitWorkspace()
        persistenceMessage = "Created default Orbit workspace data."
        persistenceIsError = false
        return
      }

      orbitWorkspace = decodedWorkspace
      persistenceMessage = nil
      persistenceIsError = false
    } catch {
      orbitWorkspace = .defaultWorkspace
      persistenceMessage = "Failed to load Orbit workspace data: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  @MainActor
  func loadServerBackedOrbitRoom(
    using client: OrbitServerBackedRoomClient
  ) async {
    do {
      var coordinator = serverBackedRoomCoordinator
      try await coordinator.connect(scope: serverBackedRoomScope, client: client)
      try applyServerBackedOrbitRoom(coordinator)
      persistenceMessage = "Loaded Orbit room from canonical server runtime."
      persistenceIsError = false
    } catch {
      persistenceMessage = "Failed to load server-backed Orbit room: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  @MainActor
  func pollServerBackedOrbitRoomLoop(
    using client: OrbitServerBackedRoomClient
  ) async {
    guard workspaceStore.workspaceURL != nil else {
      return
    }

    var retryState = OrbitServerBackedRoomTransportRetryState()

    while !Task.isCancelled {
      if retryState.shouldAttemptPersistentTransport {
        let result = await maintainPersistentServerBackedOrbitRoomLoop(using: client)
        retryState.recordPersistentTransportResult(result)

        if result == .finished {
          return
        }
      }

      do {
        try await Task.sleep(for: serverBackedRoomPollInterval)
      } catch {
        return
      }

      guard !Task.isCancelled else {
        return
      }

      await pollServerBackedOrbitRoom(using: client)
      retryState.recordPollingCycle()
    }
  }

  @MainActor
  func maintainPersistentServerBackedOrbitRoomLoop(
    using client: OrbitServerBackedRoomClient
  ) async -> OrbitServerBackedRoomPersistentTransportResult {

    while !Task.isCancelled {
      let cursor = serverBackedRoomCoordinator.roomState.session?.replayCursor

      guard
        let responses = await client.persistentTransportResponses(
          scope: serverBackedRoomScope,
          cursor: cursor,
          pollInterval: serverBackedRoomPollInterval
        )
      else {
        return .unavailable
      }

      do {
        for try await response in responses {
          try applyServerBackedOrbitRoom(response)
        }
      } catch is CancellationError {
        return .finished
      } catch {
        if OrbitServerBackedRoomTransportPolicy.shouldFallBackToPolling(after: error) {
          persistenceMessage = OrbitServerBackedRoomTransportPolicy.fallbackMessage(
            after: error
          )
          persistenceIsError = true
          return .degradedToPolling
        }
      }

      guard !Task.isCancelled else {
        return .finished
      }

      do {
        try await Task.sleep(for: serverBackedRoomPollInterval)
      } catch {
        return .finished
      }
    }

    return .finished
  }

  @MainActor
  func pollServerBackedOrbitRoom(
    using client: OrbitServerBackedRoomClient
  ) async {
    do {
      var coordinator = serverBackedRoomCoordinator
      try await coordinator.poll(client: client)
      try applyServerBackedOrbitRoom(coordinator)
    } catch {
      persistenceMessage = "Failed to refresh server-backed Orbit room: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  @MainActor
  func applyServerBackedOrbitRoom(
    _ response: OrbitPhase1RealtimeTransportResponse
  ) throws {
    var coordinator = serverBackedRoomCoordinator
    try coordinator.apply(response)
    try applyServerBackedOrbitRoom(coordinator)
  }

  @MainActor
  func applyServerBackedOrbitRoom(
    _ coordinator: OrbitServerBackedRoomCoordinator
  ) throws {
    serverBackedRoomCoordinator = coordinator

    if let projectedWorkspace = coordinator.roomState.projectedWorkspace {
      orbitWorkspace = projectedWorkspace
    }

    if persistenceIsError {
      persistenceMessage = nil
      persistenceIsError = false
    }
  }

  func persistOrbitWorkspace() {
    guard workspaceStore.workspaceURL != nil else {
      return
    }

    do {
      try persistOrbitWorkspace(orbitWorkspace)

      if persistenceIsError {
        persistenceMessage = nil
        persistenceIsError = false
      }
    } catch {
      persistenceMessage = "Failed to save Orbit workspace data: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }
}
