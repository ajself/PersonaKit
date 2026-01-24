import Foundation

public struct LoadedUserPack: Sendable, Hashable {
  public let set: PersonaSet
  public let packRoot: URL
  public let packFile: URL
  public let isDirectoryPack: Bool
}

public enum UserPackLoader {
  public static func load(
    in packsRoot: URL,
    fileClient: FileClient? = nil
  ) -> (packs: [LoadedUserPack], diagnostics: [Diagnostic]) {
    var packs: [LoadedUserPack] = []
    var diagnostics: [Diagnostic] = []
    let fileClient = fileClient ?? FileClientProvider().fileClient

    let contents: [URL]
    do {
      contents = try fileClient.contentsOfDirectory(packsRoot, [.isDirectoryKey])
    } catch {
      diagnostics.append(.warning(
        source: PersonaSource(kind: .user, url: packsRoot),
        message: "Could not read user packs directory. Fix: ensure the directory exists and is readable. (\(error.localizedDescription))"
      ))
      return (packs, diagnostics)
    }

    let sorted = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    for entry in sorted {
      let isDirectory = fileClient.isDirectory(entry)
      if isDirectory {
        loadPackDirectory(entry, fileClient: fileClient, packs: &packs, diagnostics: &diagnostics)
      } else {
        loadPackFile(entry, packs: &packs, diagnostics: &diagnostics)
      }
    }

    return (packs, diagnostics)
  }

  private static func loadPackDirectory(
    _ directory: URL,
    fileClient: FileClient,
    packs: inout [LoadedUserPack],
    diagnostics: inout [Diagnostic]
  ) {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      diagnostics.append(.warning(
        source: PersonaSource(kind: .user, url: directory),
        message: "Could not read pack folder. Fix: ensure the folder is readable."
      ))
      return
    }

    let packFiles = contents
      .filter { $0.lastPathComponent.lowercased().hasSuffix(".pack.json") }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    guard let packFile = packFiles.first else {
      diagnostics.append(.warning(
        source: PersonaSource(kind: .user, url: directory),
        message: "No .pack.json found in folder. Fix: add a pack file or remove the folder."
      ))
      return
    }

    if packFiles.count > 1 {
      diagnostics.append(.warning(
        source: PersonaSource(kind: .user, url: directory),
        message: "Multiple .pack.json files found; using \(packFile.lastPathComponent). Fix: keep one pack file per folder."
      ))
    }

    switch PersonaLoader.loadDocument(from: packFile, sourceKind: .user) {
    case .failure(let error):
      diagnostics.append(contentsOf: error.diagnostics)
    case .success(let set):
      let (extraPersonas, extraDiagnostics) = loadAdditionalPersonas(in: directory, fileClient: fileClient)
      diagnostics.append(contentsOf: extraDiagnostics)
      let combinedPersonas = set.personas + extraPersonas
      let combined = PersonaSet(source: set.source, pack: set.pack, defaults: set.defaults, personas: combinedPersonas)
      packs.append(LoadedUserPack(set: combined, packRoot: directory, packFile: packFile, isDirectoryPack: true))
    }
  }

  private static func loadPackFile(
    _ file: URL,
    packs: inout [LoadedUserPack],
    diagnostics: inout [Diagnostic]
  ) {
    guard file.pathExtension.lowercased() == "json" else { return }
    guard !isMetadataSidecar(file) else { return }

    switch PersonaLoader.loadDocument(from: file, sourceKind: .user) {
    case .failure(let error):
      diagnostics.append(contentsOf: error.diagnostics)
    case .success(let set):
      let root = file.deletingLastPathComponent()
      packs.append(LoadedUserPack(set: set, packRoot: root, packFile: file, isDirectoryPack: false))
    }
  }

  private static func loadAdditionalPersonas(
    in directory: URL,
    fileClient: FileClient
  ) -> (personas: [Persona], diagnostics: [Diagnostic]) {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      return ([], [])
    }

    let personaFiles = contents
      .filter { $0.lastPathComponent.lowercased().hasSuffix(".persona.json") }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    var personas: [Persona] = []
    var diagnostics: [Diagnostic] = []

    for file in personaFiles {
      switch PersonaLoader.loadDocument(from: file, sourceKind: .user) {
      case .failure(let error):
        diagnostics.append(contentsOf: error.diagnostics)
      case .success(let set):
        personas.append(contentsOf: set.personas)
      }
    }

    return (personas, diagnostics)
  }

  private static func isMetadataSidecar(_ url: URL) -> Bool {
    let name = url.lastPathComponent.lowercased()
    return name.hasSuffix(".meta.json") || name.hasSuffix(".metadata.json")
  }
}
