import Foundation

struct OrbitWorkspacePersistence {
  var fileManager: FileManager = .default

  func directoryURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Orbit", isDirectory: true)
  }

  func fileURL(
    for workspaceURL: URL
  ) -> URL {
    directoryURL(for: workspaceURL)
      .appendingPathComponent("orbit-workspace.json", isDirectory: false)
  }

  func loadWorkspace(
    from workspaceURL: URL
  ) throws -> OrbitWorkspace? {
    let orbitFileURL = fileURL(for: workspaceURL)

    guard fileManager.fileExists(atPath: orbitFileURL.path()) else {
      return nil
    }

    let data = try Data(contentsOf: orbitFileURL)
    return try JSONDecoder().decode(OrbitWorkspace.self, from: data)
  }

  func persist(
    _ workspace: OrbitWorkspace,
    to workspaceURL: URL
  ) throws {
    let orbitDirectoryURL = directoryURL(for: workspaceURL)
    let orbitFileURL = fileURL(for: workspaceURL)

    try fileManager.createDirectory(
      at: orbitDirectoryURL,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(workspace)
    try data.write(to: orbitFileURL, options: [.atomic])
  }
}
