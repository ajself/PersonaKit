import Foundation
import PersonaPadCore
import PersonaPadResources

extension AppStore {
  func reloadAll() {
    state.diagnostics.removeAll()
    let previousSelection = state.selectedPersonaID

    var sets: [PersonaSet] = []
    var packsByID: [String: PackMeta] = [:]
    var sourcesByID: [String: PersonaSource] = [:]
    var packLocationsByID: [String: PackLocation] = [:]
    var packLocationsBySourceURL: [URL: PackLocation] = [:]

    // 1) Built-ins from resources (BuiltIn/*.json)
    let builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: PersonaPadResources.bundle)
    if builtInURLs.isEmpty {
      state.diagnostics.append(
        .warning(
          source: PersonaSource(kind: .builtIn, url: nil),
          message:
            "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled in the app."
        ))
    } else {
      for url in builtInURLs {
        switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
        case .success(let set):
          sets.append(set)
        case .failure(let error):
          state.diagnostics.append(contentsOf: error.diagnostics)
        }
      }
    }

    // 2) User packs directory (best-effort)
    let userPacks = PersonaPadStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs
    if fileClient.fileExists(userPacks) {
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
    }

    if sets.isEmpty {
      state.diagnostics.append(
        .warning(
          source: PersonaSource(kind: .adhoc, url: nil),
          message: "No persona packs loaded. Add packs to \(userPacks.path)."
        ))
    }

    for set in sets {
      for persona in set.personas {
        packsByID[persona.id] = set.pack
        sourcesByID[persona.id] = set.source
        if let url = set.source.url, let location = packLocationsBySourceURL[url] {
          packLocationsByID[persona.id] = location
        }
      }
    }

    let merged = PersonaResolver.mergeSets(sets)
    state.diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    state.diagnostics.append(contentsOf: resolved.diagnostics)
    state.personaIndex = resolved.personasByID
    state.personaPacksByID = packsByID
    state.personaSourcesByID = sourcesByID
    state.packLocationsByPersonaID = packLocationsByID
    state.availablePacks = buildPackSelections(
      sets: sets, packLocationsBySourceURL: packLocationsBySourceURL)

    if let previousSelection, state.personaIndex.keys.contains(previousSelection) {
      state.selectedPersonaID = previousSelection
    } else {
      state.selectedPersonaID = state.personaIndex.keys.sorted().first
    }
    recomputePreview()
  }

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
