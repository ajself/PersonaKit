import Foundation
import PersonaKitCore
import PersonaKitResources

/// Pack loading and preview refresh routines for ``AppStore``.
extension AppStore {
  /// Bundles computed indexes used during reload to keep lookups consistent.
  private struct ReloadIndexes {
    let packsByID: [String: PackMeta]
    let sourcesByID: [String: PersonaSource]
    let packLocationsByID: [String: PackLocation]
  }

  /// Reloads built-in and user packs, then refreshes selections and previews.
  func reloadAll() {
    state.diagnostics.removeAll()
    let previousSelection = state.selectedPersonaID

    let userPacks = PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs
    let builtInSets = loadBuiltInSets()
    let userPackInfo = loadUserPackInfo(in: userPacks)
    let sets = builtInSets + userPackInfo.sets
    appendNoPacksWarningIfNeeded(sets: sets, userPacks: userPacks)

    let indexes = buildIndexes(
      for: sets,
      packLocationsBySourceURL: userPackInfo.packLocationsBySourceURL
    )

    let merged = PersonaResolver.mergeSets(sets)
    state.diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    state.diagnostics.append(contentsOf: resolved.diagnostics)
    state.personaIndex = resolved.personasByID
    state.personaPacksByID = indexes.packsByID
    state.personaSourcesByID = indexes.sourcesByID
    state.packLocationsByPersonaID = indexes.packLocationsByID
    state.availablePacks = buildPackSelections(
      sets: sets, packLocationsBySourceURL: userPackInfo.packLocationsBySourceURL)

    restoreSelection(previousSelection: previousSelection)
    recomputePreview()
  }

  /// Recomputes prompt and JSON previews for the selected persona.
  func recomputePreview() {
    guard let id = state.selectedPersonaID,
      let persona = state.personaIndex[id]?.persona
    else {
      state.promptPreview = ""
      updateJSONPreview("", scheduleFormat: false)
      return
    }
    state.promptPreview = PersonaOutputRenderer.prompt(
      persona: persona, sections: state.composerValues)
    updateJSONPreview(buildPersonaJSON(persona: persona, prettyPrinted: true), scheduleFormat: true)
  }

  private func loadBuiltInSets() -> [PersonaSet] {
    var sets: [PersonaSet] = []
    let builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: PersonaKitResources.bundle)
    if builtInURLs.isEmpty {
      state.diagnostics.append(
        .warning(
          source: PersonaSource(kind: .builtIn, url: nil),
          message:
            "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled in the app."
        ))
      return sets
    }

    for url in builtInURLs {
      switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
      case .success(let set):
        sets.append(set)
      case .failure(let error):
        state.diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return sets
  }

  private func loadUserPackInfo(
    in userPacks: URL
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
    state.diagnostics.append(contentsOf: loaded.diagnostics)
    return (sets: sets, packLocationsBySourceURL: packLocationsBySourceURL)
  }

  private func appendNoPacksWarningIfNeeded(sets: [PersonaSet], userPacks: URL) {
    guard sets.isEmpty else { return }
    state.diagnostics.append(
      .warning(
        source: PersonaSource(kind: .adhoc, url: nil),
        message: "No persona packs loaded. Add packs to \(userPacks.path)."
      ))
  }

  private func buildIndexes(
    for sets: [PersonaSet],
    packLocationsBySourceURL: [URL: PackLocation]
  ) -> ReloadIndexes {
    var packsByID: [String: PackMeta] = [:]
    var sourcesByID: [String: PersonaSource] = [:]
    var packLocationsByID: [String: PackLocation] = [:]

    for set in sets {
      for persona in set.personas {
        packsByID[persona.id] = set.pack
        sourcesByID[persona.id] = set.source
        if let url = set.source.url, let location = packLocationsBySourceURL[url] {
          packLocationsByID[persona.id] = location
        }
      }
    }

    return ReloadIndexes(
      packsByID: packsByID,
      sourcesByID: sourcesByID,
      packLocationsByID: packLocationsByID
    )
  }

  private func restoreSelection(previousSelection: String?) {
    if let previousSelection, state.personaIndex.keys.contains(previousSelection) {
      state.selectedPersonaID = previousSelection
    } else {
      state.selectedPersonaID = state.personaIndex.keys.sorted().first
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
