import Foundation

extension OrbitPanelView {
  func orbitDirectoryURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Orbit", isDirectory: true)
  }

  func orbitWorkspaceFileURL(
    for workspaceURL: URL
  ) -> URL {
    orbitDirectoryURL(for: workspaceURL)
      .appendingPathComponent("orbit-workspace.json", isDirectory: false)
  }

  func loadOrbitWorkspace() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      orbitWorkspace = .defaultWorkspace
      persistenceMessage = "Open a workspace to persist Orbit runtime data."
      persistenceIsError = false
      return
    }

    let fileURL = orbitWorkspaceFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      orbitWorkspace = .defaultWorkspace
      persistOrbitWorkspace()
      persistenceMessage = "Created default Orbit workspace data."
      persistenceIsError = false
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let decodedWorkspace = try JSONDecoder().decode(OrbitWorkspace.self, from: data)
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
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    let directoryURL = orbitDirectoryURL(for: workspaceURL)
    let fileURL = orbitWorkspaceFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(orbitWorkspace)
      try data.write(to: fileURL, options: [.atomic])

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
