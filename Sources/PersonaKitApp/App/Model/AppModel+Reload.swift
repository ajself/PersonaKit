import Dependencies
import Foundation
import PersonaKitCore
import PersonaKitResources

/// Pack loading and preview refresh routines for ``AppModel``.
extension AppModel {
  /// Bundles computed indexes used during reload to keep lookups consistent.
  private struct ReloadIndexes {
    let packsByID: [String: PackMeta]
    let sourcesByID: [String: PersonaSource]
    let packLocationsByID: [String: PackLocation]
  }

  /// Reloads built-in and user packs, then refreshes selections and previews.
  func reloadAll() {
    @Dependency(\.fileClient) var fileClient
    diagnostics.removeAll()
    let previousSelection = composer.selectedPersonaID

    let userPacks = PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs
    let builtIn = PersonaBuiltInPackLoader.loadBuiltInSets(
      bundle: PersonaKitResources.bundle,
      missingResourcesMessage:
        "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled in the app."
    )
    diagnostics.append(contentsOf: builtIn.diagnostics)
    let userPackInfo = loadUserPackInfo(in: userPacks, fileClient: fileClient)
    let sets = builtIn.sets + userPackInfo.sets
    appendNoPacksWarningIfNeeded(sets: sets, userPacks: userPacks)

    let indexes = buildIndexes(
      for: sets,
      packLocationsBySourceURL: userPackInfo.packLocationsBySourceURL
    )

    let merged = PersonaResolver.mergeSets(sets)
    diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    diagnostics.append(contentsOf: resolved.diagnostics)
    personaIndex = resolved.personasByID
    personaPacksByID = indexes.packsByID
    personaSourcesByID = indexes.sourcesByID
    packLocationsByPersonaID = indexes.packLocationsByID
    availablePacks = buildPackSelections(
      sets: sets, packLocationsBySourceURL: userPackInfo.packLocationsBySourceURL)

    restoreSelection(previousSelection: previousSelection)
    requestPreviewRecompute()
    handlePreviewRecomputeIfNeeded()
  }

  /// Recomputes prompt and JSON previews for the selected persona.
  func recomputePreview() {
    guard let id = composer.selectedPersonaID,
      let persona = personaIndex[id]?.persona
    else {
      preview.promptPreview = ""
      updateJSONPreview("", scheduleFormat: false)
      return
    }
    preview.promptPreview = PersonaOutputRenderer.prompt(
      persona: persona, sections: composer.composerValues)
    let json = PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true) ?? ""
    updateJSONPreview(json, scheduleFormat: true)
  }

  private func loadUserPackInfo(
    in userPacks: URL,
    fileClient: FileClient
  ) -> (sets: [PersonaSet], packLocationsBySourceURL: [URL: PackLocation]) {
    guard fileClient.fileExists(userPacks) else {
      return (sets: [], packLocationsBySourceURL: [:])
    }

    var sets: [PersonaSet] = []
    var packLocationsBySourceURL: [URL: PackLocation] = [:]
    let loaded = UserPackLoader.load(in: userPacks)
    for pack in loaded.packs {
      sets.append(pack.set)
      packLocationsBySourceURL[pack.packFile] = PackLocation(
        packRoot: pack.packRoot,
        packFile: pack.packFile,
        isDirectoryPack: pack.isDirectoryPack
      )
    }
    diagnostics.append(contentsOf: loaded.diagnostics)
    return (sets: sets, packLocationsBySourceURL: packLocationsBySourceURL)
  }

  private func appendNoPacksWarningIfNeeded(sets: [PersonaSet], userPacks: URL) {
    guard sets.isEmpty else { return }
    diagnostics.append(
      .warning(
        source: PersonaSource(kind: .adhoc, url: nil),
        message: "No persona packs loaded. Add packs to \(userPacks.path)."
      ))
  }

  private func buildIndexes(
    for sets: [PersonaSet],
    packLocationsBySourceURL: [URL: PackLocation]
  ) -> ReloadIndexes {
    let baseIndexes = PersonaIndexBuilder.buildIndexes(sets: sets)
    var packLocationsByID: [String: PackLocation] = [:]

    for set in sets {
      for persona in set.personas {
        if let url = set.source.url, let location = packLocationsBySourceURL[url] {
          packLocationsByID[persona.id] = location
        }
      }
    }

    return ReloadIndexes(
      packsByID: baseIndexes.packsByID,
      sourcesByID: baseIndexes.sourcesByID,
      packLocationsByID: packLocationsByID
    )
  }

  private func restoreSelection(previousSelection: String?) {
    if let previousSelection, personaIndex.keys.contains(previousSelection) {
      composer.selectedPersonaID = previousSelection
    } else {
      composer.selectedPersonaID = personaIndex.keys.sorted().first
    }
  }

  private func buildPackSelections(
    sets: [PersonaSet],
    packLocationsBySourceURL: [URL: PackLocation]
  ) -> [PackSelection] {
    var selectionsByURL: [URL: PackSelection] = [:]

    for set in sets {
      guard let packFile = set.source.url else { continue }
      let canonical = packFile.resolvingSymlinksInPath().standardizedFileURL
      if selectionsByURL[canonical] != nil { continue }

      let location = packLocationsBySourceURL[packFile] ?? packLocationsBySourceURL[canonical]
      let packRoot = location?.packRoot ?? packFile.deletingLastPathComponent()
      let isDirectoryPack = location?.isDirectoryPack ?? false

      let selection = PackSelection(
        id: canonical.path,
        pack: set.pack,
        source: set.source,
        packFile: packFile,
        packRoot: packRoot,
        isDirectoryPack: isDirectoryPack
      )
      selectionsByURL[canonical] = selection
    }

    return selectionsByURL.values.sorted { PackSelection.sortKey($0) < PackSelection.sortKey($1) }
  }
}
