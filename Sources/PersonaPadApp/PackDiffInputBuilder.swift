import Dependencies
import Foundation
import PersonaPadCore

struct PackDiffInputResult: Equatable {
  let records: [PersonaDiffRecord]
  let diagnostics: [Diagnostic]
}

enum PackDiffInputBuilder {
  static func build(for selection: PackSelection, fileClient: FileClient? = nil) -> PackDiffInputResult {
    var records: [PersonaDiffRecord] = []
    var diagnostics: [Diagnostic] = []
    let fileClient = fileClient ?? PackDiffEnvironment().fileClient

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
        records.append(PersonaDiffRecord(key: key, id: displayID, name: displayName, contentHash: hash))
      }
    }
  }

  private static func loadPersonaFiles(in directory: URL, fileClient: FileClient) -> [URL] {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      return []
    }
    return contents
      .filter { $0.lastPathComponent.lowercased().hasSuffix(".persona.json") }
      .filter { !isMetadataSidecar($0) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private static func isMetadataSidecar(_ url: URL) -> Bool {
    let name = url.lastPathComponent.lowercased()
    return name.hasSuffix(".meta.json") || name.hasSuffix(".metadata.json")
  }
}

private struct PackDiffEnvironment {
  @Dependency(\.fileClient) var fileClient
}
