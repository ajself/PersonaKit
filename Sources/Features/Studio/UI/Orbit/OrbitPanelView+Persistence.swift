import Foundation
import OrbitServerRuntime

enum OrbitServerBackedRoomTransportPolicy {
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

    if await maintainPersistentServerBackedOrbitRoomLoop(using: client) {
      return
    }

    while !Task.isCancelled {
      do {
        try await Task.sleep(for: serverBackedRoomPollInterval)
      } catch {
        return
      }

      guard !Task.isCancelled else {
        return
      }

      await pollServerBackedOrbitRoom(using: client)
    }
  }

  @MainActor
  func maintainPersistentServerBackedOrbitRoomLoop(
    using client: OrbitServerBackedRoomClient
  ) async -> Bool {
    var attemptedPersistentTransport = false

    while !Task.isCancelled {
      let cursor = serverBackedRoomCoordinator.roomState.session?.replayCursor

      guard
        let responses = await client.persistentTransportResponses(
          scope: serverBackedRoomScope,
          cursor: cursor,
          pollInterval: serverBackedRoomPollInterval
        )
      else {
        return attemptedPersistentTransport
      }

      attemptedPersistentTransport = true

      do {
        for try await response in responses {
          try applyServerBackedOrbitRoom(response)
        }
      } catch {
        if OrbitServerBackedRoomTransportPolicy.shouldFallBackToPolling(after: error) {
          persistenceMessage = OrbitServerBackedRoomTransportPolicy.fallbackMessage(
            after: error
          )
          persistenceIsError = true
          return false
        }
      }

      guard !Task.isCancelled else {
        return true
      }

      do {
        try await Task.sleep(for: serverBackedRoomPollInterval)
      } catch {
        return true
      }
    }

    return attemptedPersistentTransport
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
