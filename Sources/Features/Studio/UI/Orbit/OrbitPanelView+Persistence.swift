import Foundation

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
  var orbitPersistence: OrbitWorkspacePersistence {
    OrbitWorkspacePersistence()
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
