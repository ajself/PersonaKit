import Foundation
import OrbitServerRuntime

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
      serverBackedRoomCoordinator = coordinator
      if let projectedWorkspace = coordinator.roomState.projectedWorkspace {
        orbitWorkspace = projectedWorkspace
      }
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

    while !Task.isCancelled {
      do {
        try await Task.sleep(for: .seconds(2))
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
  func pollServerBackedOrbitRoom(
    using client: OrbitServerBackedRoomClient
  ) async {
    do {
      var coordinator = serverBackedRoomCoordinator
      try await coordinator.poll(client: client)
      serverBackedRoomCoordinator = coordinator
      if let projectedWorkspace = coordinator.roomState.projectedWorkspace {
        orbitWorkspace = projectedWorkspace
      }
      if persistenceIsError {
        persistenceMessage = nil
        persistenceIsError = false
      }
    } catch {
      persistenceMessage = "Failed to refresh server-backed Orbit room: \(error.localizedDescription)"
      persistenceIsError = true
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
