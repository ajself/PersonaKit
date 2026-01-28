import Dependencies
import Foundation
import PersonaKitCore

/// Output produced by ``PackDiffInputBuilder`` for diff computation.
struct PackDiffInputResult: Equatable {
  let records: [PersonaDiffRecord]
  let diagnostics: [Diagnostic]
}

/// Builds diff inputs from persona packs on disk.
enum PackDiffInputBuilder {
  /// Loads personas for the given pack selection and prepares diff records.
  static func build(
    for selection: PackSelection, fileClient: FileClient? = nil
  ) -> PackDiffInputResult {
    var records: [PersonaDiffRecord] = []
    var diagnostics: [Diagnostic] = []
    @Dependency(\.fileClient) var resolvedFileClient
    let fileClient = fileClient ?? resolvedFileClient

    appendRecords(
      from: selection.packFile,
      sourceKind: selection.source.kind,
      fileURL: selection.packFile,
      records: &records,
      diagnostics: &diagnostics
    )

    if selection.isDirectoryPack {
      let personaFiles = loadPersonaFiles(in: selection.packRoot, fileClient: fileClient)
      for file in personaFiles {
        appendRecords(
          from: file,
          sourceKind: .user,
          fileURL: file,
          records: &records,
          diagnostics: &diagnostics
        )
      }
    }

    return PackDiffInputResult(records: records, diagnostics: diagnostics)
  }

  /// Appends diff records for a specific pack file.
  private static func appendRecords(
    from url: URL,
    sourceKind: PersonaSource.Kind,
    fileURL: URL,
    records: inout [PersonaDiffRecord],
    diagnostics: inout [Diagnostic]
  ) {
    switch PersonaLoader.loadDocument(from: url, sourceKind: sourceKind) {
    case .failure(let error):
      diagnostics.append(contentsOf: error.diagnostics)
    case .success(let set):
      for persona in set.personas {
        let trimmedID = persona.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = PackDiffBuilder.personaKey(id: persona.id, fileURL: fileURL)
        let name = persona.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? nil : name
        let displayID = trimmedID.isEmpty ? key : trimmedID
        let hash = PackDiffBuilder.contentHash(for: persona)
        records.append(
          PersonaDiffRecord(key: key, id: displayID, name: displayName, contentHash: hash))
      }
    }
  }

  /// Returns persona JSON files inside a directory pack, excluding sidecars.
  private static func loadPersonaFiles(in directory: URL, fileClient: FileClient) -> [URL] {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      return []
    }
    return
      contents
      .filter { $0.lastPathComponent.lowercased().hasSuffix(".persona.json") }
      .filter { !isMetadataSidecar($0) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// Returns true when the file is a metadata sidecar for a persona file.
  private static func isMetadataSidecar(_ url: URL) -> Bool {
    let name = url.lastPathComponent.lowercased()
    return name.hasSuffix(".meta.json") || name.hasSuffix(".metadata.json")
  }
}
