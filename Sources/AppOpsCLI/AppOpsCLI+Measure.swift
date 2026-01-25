import AppOpsCore
import Foundation
import PersonaKitCore

extension AppOpsCLI {
  private struct PackExportDocument: Codable {
    let schemaVersion: Int
    let documentType: String
    let pack: PackMeta
    let defaults: PackDefaults?
    let personas: [Persona]
  }

  static func measureCompose(
    resolved: PersonaResolver.ResolutionResult
  ) -> ComposeMetrics {
    let personas = resolved.personasByID.keys.sorted().compactMap {
      resolved.personasByID[$0]?.persona
    }
    let (result, duration) = measure {
      var promptBytes = 0
      var jsonBytes = 0
      for persona in personas {
        let sections = sampleSections(for: persona)
        let prompt = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
        promptBytes += prompt.utf8.count
        if let json = PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true) {
          jsonBytes += json.utf8.count
        }
      }
      return (promptBytes: promptBytes, jsonBytes: jsonBytes)
    }
    return ComposeMetrics(
      durationSeconds: duration,
      personaCount: personas.count,
      promptBytesTotal: result.promptBytes,
      jsonBytesTotal: result.jsonBytes
    )
  }

  static func measureDiff(left: URL, right: URL) throws -> DiffMetrics {
    let leftSet = try loadSet(url: left, sourceKind: .project)
    let rightSet = try loadSet(url: right, sourceKind: .project)

    let (diff, duration) = measure {
      let leftRecords = diffRecords(for: leftSet)
      let rightRecords = diffRecords(for: rightSet)
      return PackDiffBuilder.diff(left: leftRecords, right: rightRecords)
    }

    return DiffMetrics(
      durationSeconds: duration,
      leftPersonaCount: leftSet.personas.count,
      rightPersonaCount: rightSet.personas.count,
      addedCount: diff.added.count,
      removedCount: diff.removed.count,
      modifiedCount: diff.modified.count
    )
  }

  static func measureImport(
    selection: URL,
    destinationRoot: URL,
    fileClient: FileClient
  ) throws -> ImportMetrics {
    try fileClient.createDirectory(destinationRoot, true)
    let (planResult, planDuration) = measure {
      PersonaPackImportPlan.plan(from: selection, fileClient: fileClient)
    }
    let plan: PersonaPackImportPlan
    switch planResult {
    case .success(let result):
      plan = result
    case .failure(let error):
      throw AppOpsError(error.userFacingMessage)
    }

    let existing = existingPackDirectoryNames(in: destinationRoot, fileClient: fileClient)
    let preferred = PersonaKitStorage.preferredPackDirectoryName(for: plan.pack)
    let folderName = PersonaKitStorage.uniquePackDirectoryName(
      preferred: preferred, existing: existing)
    let destination = destinationRoot.appendingPathComponent(folderName, isDirectory: true)
    let tempFolderName = ".import_tmp_\(UUID().uuidString)"
    let tempDestination = destinationRoot.appendingPathComponent(tempFolderName, isDirectory: true)

    let (copyResult, copyDuration) = try measure {
      try copyImportFiles(
        plan: plan,
        tempDestination: tempDestination,
        finalDestination: destination,
        fileClient: fileClient
      )
    }

    return ImportMetrics(
      planDurationSeconds: planDuration,
      copyDurationSeconds: copyDuration,
      filesCopied: copyResult.filesCopied,
      bytesCopied: copyResult.bytesCopied,
      destinationRoot: destination.path
    )
  }

  static func measureExport(
    sets: [PersonaSet],
    outputRoot: URL,
    fileClient: FileClient
  ) throws -> ExportMetrics {
    guard let set = sets.first else {
      throw AppOpsError("No persona sets available for export.")
    }
    try fileClient.createDirectory(outputRoot, true)
    let fileName = "\(PersonaKitStorage.preferredPackDirectoryName(for: set.pack)).pack.json"
    let outputPath = outputRoot.appendingPathComponent(fileName)
    let (bytesWritten, duration) = try measure {
      let document = PackExportDocument(
        schemaVersion: 1,
        documentType: "personaPack",
        pack: set.pack,
        defaults: set.defaults,
        personas: set.personas
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(document)
      try fileClient.writeData(data, outputPath, .atomic)
      return Int64(data.count)
    }
    return ExportMetrics(
      durationSeconds: duration,
      bytesWritten: bytesWritten,
      outputPath: outputPath.path
    )
  }

  static func measure<T>(_ work: () throws -> T) rethrows -> (T, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try work()
    let end = DispatchTime.now().uptimeNanoseconds
    let duration = Double(end - start) / 1_000_000_000
    return (value, duration)
  }

  private static func copyImportFiles(
    plan: PersonaPackImportPlan,
    tempDestination: URL,
    finalDestination: URL,
    fileClient: FileClient
  ) throws -> (filesCopied: Int, bytesCopied: Int64) {
    var bytesCopied: Int64 = 0
    do {
      try fileClient.createDirectory(tempDestination, true)
      for file in plan.filesToCopy {
        guard let relativePath = plan.relativePath(for: file) else {
          throw AppOpsError("Import file is outside the source root: \(file.path)")
        }
        let target = tempDestination.appendingPathComponent(relativePath)
        let targetFolder = target.deletingLastPathComponent()
        try fileClient.createDirectory(targetFolder, true)
        try fileClient.copyItem(file, target)
        bytesCopied += fileSize(file)
      }
      try fileClient.moveItem(tempDestination, finalDestination)
    } catch {
      try? fileClient.removeItem(tempDestination)
      throw error
    }
    return (plan.filesToCopy.count, bytesCopied)
  }

  private static func loadSet(url: URL, sourceKind: PersonaSource.Kind) throws -> PersonaSet {
    switch PersonaLoader.loadDocument(from: url, sourceKind: sourceKind) {
    case .success(let set):
      return set
    case .failure(let error):
      let message = error.diagnostics.first?.userFacingMessage ?? "Failed to load pack."
      throw AppOpsError(message)
    }
  }

  private static func diffRecords(for set: PersonaSet) -> [PersonaDiffRecord] {
    set.personas.map { persona in
      let key = PackDiffBuilder.personaKey(id: persona.id, fileURL: nil)
      return PersonaDiffRecord(
        key: key,
        id: persona.id,
        name: persona.name,
        contentHash: PackDiffBuilder.contentHash(for: persona)
      )
    }
  }

  private static func sampleSections(for persona: Persona) -> [String: String] {
    let keys =
      persona.template?.sections?.map { $0.key }
      ?? ["context", "goal", "constraints", "evidence", "task"]
    var sections: [String: String] = [:]
    for key in keys {
      sections[key] = "Sample \(key)"
    }
    return sections
  }

  private static func existingPackDirectoryNames(
    in packsRoot: URL,
    fileClient: FileClient
  ) -> Set<String> {
    guard let contents = try? fileClient.contentsOfDirectory(packsRoot, [.isDirectoryKey]) else {
      return []
    }
    return Set(
      contents.compactMap { url in
        fileClient.isDirectory(url) ? url.lastPathComponent : nil
      }
    )
  }

  private static func fileSize(_ url: URL) -> Int64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
  }
}
