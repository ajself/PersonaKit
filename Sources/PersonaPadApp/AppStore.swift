import Dependencies
import Foundation
import Observation
import PersonaPadCore
import PersonaPadResources
import SwiftUI

struct SidebarSearchFocusRequest: Equatable {
  let id: UUID
  let shouldFocus: Bool
}

struct ComposerFocusRequest: Equatable {
  let id: UUID
  let sectionKey: String
}

struct PackLocation: Equatable {
  let packRoot: URL
  let packFile: URL
  let isDirectoryPack: Bool
}

struct PackSelection: Identifiable, Hashable {
  let id: String
  let pack: PackMeta
  let source: PersonaSource
  let packFile: URL
  let packRoot: URL
  let isDirectoryPack: Bool

  var displayName: String {
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty && !id.isEmpty && name != id {
      return "\(name) (\(id))"
    }
    if !name.isEmpty {
      return name
    }
    if !id.isEmpty {
      return id
    }
    return "Unknown Pack"
  }

  static func sortKey(_ selection: PackSelection) -> (String, String, String) {
    (
      selection.displayName,
      selection.pack.id,
      selection.packFile.path
    )
  }
}

@MainActor
@Observable
final class AppStore {
  struct State {
    var diagnostics: [Diagnostic]
    var personaIndex: [String: ResolvedPersona]
    var personaPacksByID: [String: PackMeta]
    var personaSourcesByID: [String: PersonaSource]
    var packLocationsByPersonaID: [String: PackLocation]
    var availablePacks: [PackSelection]

    var selectedPersonaID: String?
    var composerValues: [String: String]
    var promptPreview: String

    var searchText: String
    var selectedTag: String?
    var activeFilterTags: [String]
    var activeSourceKinds: Set<PersonaSource.Kind>
    var savedFilters: [SavedFilter]
    var selectedSavedFilterID: String?
    var pinnedPersonaIDs: Set<String>
    var isPinnedViewActive: Bool
    var sidebarSearchFocusRequest: SidebarSearchFocusRequest
    var isSidebarSearchFocused: Bool
    var composerFocusRequest: ComposerFocusRequest?

    init(
      diagnostics: [Diagnostic] = [],
      personaIndex: [String: ResolvedPersona] = [:],
      personaPacksByID: [String: PackMeta] = [:],
      personaSourcesByID: [String: PersonaSource] = [:],
      packLocationsByPersonaID: [String: PackLocation] = [:],
      availablePacks: [PackSelection] = [],
      selectedPersonaID: String? = nil,
      composerValues: [String: String] = [:],
      promptPreview: String = "",
      searchText: String = "",
      selectedTag: String? = nil,
      activeFilterTags: [String] = [],
      activeSourceKinds: Set<PersonaSource.Kind> = [],
      savedFilters: [SavedFilter] = [],
      selectedSavedFilterID: String? = nil,
      pinnedPersonaIDs: Set<String> = [],
      isPinnedViewActive: Bool = false,
      sidebarSearchFocusRequest: SidebarSearchFocusRequest,
      isSidebarSearchFocused: Bool = false,
      composerFocusRequest: ComposerFocusRequest? = nil
    ) {
      self.diagnostics = diagnostics
      self.personaIndex = personaIndex
      self.personaPacksByID = personaPacksByID
      self.personaSourcesByID = personaSourcesByID
      self.packLocationsByPersonaID = packLocationsByPersonaID
      self.availablePacks = availablePacks
      self.selectedPersonaID = selectedPersonaID
      self.composerValues = composerValues
      self.promptPreview = promptPreview
      self.searchText = searchText
      self.selectedTag = selectedTag
      self.activeFilterTags = activeFilterTags
      self.activeSourceKinds = activeSourceKinds
      self.savedFilters = savedFilters
      self.selectedSavedFilterID = selectedSavedFilterID
      self.pinnedPersonaIDs = pinnedPersonaIDs
      self.isPinnedViewActive = isPinnedViewActive
      self.sidebarSearchFocusRequest = sidebarSearchFocusRequest
      self.isSidebarSearchFocused = isSidebarSearchFocused
      self.composerFocusRequest = composerFocusRequest
    }
  }

  enum Action {
    case task
    case reloadAll
    case importPack
    case revealStorageRoot
    case revealSelectedPack
    case removeSelectedPack
    case copyPromptToClipboard
    case requestSidebarSearchFocus
    case requestSidebarSearchBlur
    case requestComposerFocus(sectionKey: String)
    case setSidebarSearchFocused(Bool)
    case setSelectedPersonaID(String?)
    case setComposerValue(key: String, value: String)
    case setSearchText(String)
    case setSelectedTag(String?)
    case applyAllPersonasFilter
    case applySavedFilter(SavedFilter)
    case saveCurrentFilter(name: String)
    case renameSavedFilter(id: String, newName: String)
    case deleteSavedFilter(id: String)
    case setPinnedViewActive
    case togglePinnedPersona(id: String)
  }

  @ObservationIgnored
  @Dependency(\.fileClient) private var fileClient

  @ObservationIgnored
  @Dependency(\.appClient) private var appClient

  @ObservationIgnored
  @Dependency(\.uuid) private var uuid

  private let savedFiltersStore: SavedFiltersStore
  private let pinnedPersonasStore: PinnedPersonasStore
  private var isApplyingSavedFilter = false

  private(set) var state: State

  static let allPersonasFilterID = "all-personas"

  init(
    savedFiltersStore: SavedFiltersStore = SavedFiltersStore(),
    pinnedPersonasStore: PinnedPersonasStore = PinnedPersonasStore()
  ) {
    self.savedFiltersStore = savedFiltersStore
    self.pinnedPersonasStore = pinnedPersonasStore
    let focusRequest = SidebarSearchFocusRequest(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
      shouldFocus: false
    )
    self.state = State(sidebarSearchFocusRequest: focusRequest)

    state.savedFilters = savedFiltersStore.load()
    state.selectedSavedFilterID = Self.allPersonasFilterID
    state.pinnedPersonaIDs = Set(pinnedPersonasStore.load())
  }

  var canRevealSelectedPack: Bool {
    guard let location = selectedPackLocation else { return false }
    return location.isDirectoryPack
  }

  var canRemoveSelectedPack: Bool {
    guard let location = selectedPackLocation,
          let personaID = state.selectedPersonaID,
          let source = state.personaSourcesByID[personaID] else { return false }
    return location.isDirectoryPack && source.kind == .user
  }

  func send(_ action: Action) {
    switch action {
    case .task, .reloadAll:
      reloadAll()
    case .importPack:
      importPack()
    case .revealStorageRoot:
      revealStorageRoot()
    case .revealSelectedPack:
      revealSelectedPack()
    case .removeSelectedPack:
      removeSelectedPack()
    case .copyPromptToClipboard:
      copyPromptToClipboard()
    case .requestSidebarSearchFocus:
      state.sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: uuid(), shouldFocus: true)
    case .requestSidebarSearchBlur:
      state.sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: uuid(), shouldFocus: false)
    case .requestComposerFocus(let sectionKey):
      state.composerFocusRequest = ComposerFocusRequest(id: uuid(), sectionKey: sectionKey)
    case .setSidebarSearchFocused(let isFocused):
      state.isSidebarSearchFocused = isFocused
    case .setSelectedPersonaID(let id):
      state.selectedPersonaID = id
      recomputePreview()
    case .setComposerValue(let key, let value):
      state.composerValues[key] = value
      recomputePreview()
    case .setSearchText(let text):
      state.searchText = text
      if !isApplyingSavedFilter {
        state.selectedSavedFilterID = nil
      }
    case .setSelectedTag(let tag):
      state.selectedTag = tag
      if let tag, !tag.isEmpty {
        state.activeFilterTags = [tag]
      } else {
        state.activeFilterTags = []
      }
      if !isApplyingSavedFilter {
        state.selectedSavedFilterID = nil
      }
    case .applyAllPersonasFilter:
      state.isPinnedViewActive = false
      applySavedFilterState(
        id: Self.allPersonasFilterID,
        queryText: "",
        tags: [],
        sources: []
      )
    case .applySavedFilter(let filter):
      state.isPinnedViewActive = false
      applySavedFilterState(
        id: filter.id,
        queryText: filter.queryText,
        tags: filter.selectedTags,
        sources: filter.selectedSources
      )
    case .saveCurrentFilter(let name):
      saveCurrentFilter(name: name)
    case .renameSavedFilter(let id, let newName):
      renameSavedFilter(id: id, newName: newName)
    case .deleteSavedFilter(let id):
      deleteSavedFilter(id: id)
    case .setPinnedViewActive:
      state.isPinnedViewActive = true
      state.selectedSavedFilterID = nil
    case .togglePinnedPersona(let id):
      togglePinnedPersona(id: id)
    }
  }

  func bindingForSearchText() -> Binding<String> {
    Binding(
      get: { self.state.searchText },
      set: { self.send(.setSearchText($0)) }
    )
  }

  func bindingForSelectedPersonaID() -> Binding<String?> {
    Binding(
      get: { self.state.selectedPersonaID },
      set: { self.send(.setSelectedPersonaID($0)) }
    )
  }

  func bindingForComposerValue(key: String) -> Binding<String> {
    Binding(
      get: { self.state.composerValues[key] ?? "" },
      set: { self.send(.setComposerValue(key: key, value: $0)) }
    )
  }

  private func reloadAll() {
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
      state.diagnostics.append(.warning(
        source: PersonaSource(kind: .builtIn, url: nil),
        message: "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled in the app."
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
      state.diagnostics.append(.warning(
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
    state.availablePacks = buildPackSelections(sets: sets, packLocationsBySourceURL: packLocationsBySourceURL)

    if let previousSelection, state.personaIndex.keys.contains(previousSelection) {
      state.selectedPersonaID = previousSelection
    } else {
      state.selectedPersonaID = state.personaIndex.keys.sorted().first
    }
    recomputePreview()
  }

  private func recomputePreview() {
    guard let id = state.selectedPersonaID,
          let persona = state.personaIndex[id]?.persona else {
      state.promptPreview = ""
      return
    }
    state.promptPreview = PersonaOutputRenderer.prompt(persona: persona, sections: state.composerValues)
  }

  private func importPack() {
    guard let selection = appClient.selectPackURL() else { return }

    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      appClient.presentError(
        "Import Failed",
        "Could not create PersonaPad storage folders. Fix: check permissions for Application Support."
      )
      return
    }

    let planResult = PersonaPackImportPlan.plan(from: selection)
    switch planResult {
    case .failure(let error):
      appClient.presentError("Import Failed", error.userFacingMessage)
      return
    case .success(let plan):
      let existingNames = existingPackDirectoryNames(in: paths.packs)
      let preferred = PersonaPadStorage.preferredPackDirectoryName(for: plan.pack)
      let folderName = PersonaPadStorage.uniquePackDirectoryName(preferred: preferred, existing: existingNames)
      let destination = paths.packs.appendingPathComponent(folderName, isDirectory: true)
      let tempFolderName = ".import_tmp_\(uuid().uuidString)"
      let tempDestination = paths.packs.appendingPathComponent(tempFolderName, isDirectory: true)

      do {
        try fileClient.createDirectory(tempDestination, true)
        for file in plan.filesToCopy {
          guard let relativePath = plan.relativePath(for: file) else {
            throw ImportCopyFailure.outsideRoot
          }
          let target = tempDestination.appendingPathComponent(relativePath)
          let targetFolder = target.deletingLastPathComponent()
          try fileClient.createDirectory(targetFolder, true)
          try fileClient.copyItem(file, target)
        }
        try fileClient.moveItem(tempDestination, destination)
      } catch {
        try? fileClient.removeItem(tempDestination)
        if case ImportCopyFailure.outsideRoot = error {
          appClient.presentError(
            "Import Failed",
            "One or more files are outside the selected folder. Fix: ensure all pack files live under the pack folder."
          )
          return
        }
        appClient.presentError(
          "Import Failed",
          "Could not copy pack files. Fix: ensure the destination is writable. (\(error.localizedDescription))"
        )
        return
      }
    }

    reloadAll()
  }

  private func revealStorageRoot() {
    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      appClient.presentError(
        "Reveal Failed",
        "Could not create PersonaPad storage folders. Fix: check permissions for Application Support."
      )
      return
    }
    appClient.openURL(paths.root)
  }

  private func revealSelectedPack() {
    guard let location = selectedPackLocation, location.isDirectoryPack else {
      appClient.presentError("Reveal Failed", "Selected pack is not a user pack folder.")
      return
    }
    appClient.openURL(location.packRoot)
  }

  private func removeSelectedPack() {
    guard let location = selectedPackLocation,
          let personaID = state.selectedPersonaID,
          let source = state.personaSourcesByID[personaID],
          location.isDirectoryPack,
          source.kind == .user else {
      appClient.presentError("Remove Failed", "Only user packs stored in PersonaPad can be removed.")
      return
    }

    guard appClient.confirmRemovePack() else { return }

    do {
      try fileClient.removeItem(location.packRoot)
      reloadAll()
    } catch {
      appClient.presentError(
        "Remove Failed",
        "Could not delete the pack folder. Fix: check permissions. (\(error.localizedDescription))"
      )
    }
  }

  private func copyPromptToClipboard() {
    appClient.copyToClipboard(state.promptPreview)
  }

  private var selectedPackLocation: PackLocation? {
    guard let personaID = state.selectedPersonaID else { return nil }
    return state.packLocationsByPersonaID[personaID]
  }

  private func ensureStorageDirectories() throws -> PersonaPadStoragePaths {
    let paths = PersonaPadStoragePaths.standard(homeDirectory: fileClient.homeDirectory())
    try fileClient.createDirectory(paths.packs, true)
    try fileClient.createDirectory(paths.state, true)
    return paths
  }

  private func existingPackDirectoryNames(in packsRoot: URL) -> Set<String> {
    guard let contents = try? fileClient.contentsOfDirectory(packsRoot, [.isDirectoryKey]) else {
      return []
    }
    return Set(contents.compactMap { url in
      let isDirectory = fileClient.isDirectory(url)
      return isDirectory ? url.lastPathComponent : nil
    })
  }

  private func applySavedFilterState(id: String?, queryText: String, tags: [String], sources: [String]) {
    isApplyingSavedFilter = true
    state.selectedSavedFilterID = id
    state.searchText = queryText
    state.activeFilterTags = tags
    if tags.count == 1, let only = tags.first {
      state.selectedTag = only
    } else {
      state.selectedTag = nil
    }
    state.activeSourceKinds = parseSourceKinds(from: sources)
    isApplyingSavedFilter = false
  }

  private func saveCurrentFilter(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let tags = Array(Set(state.activeFilterTags)).sorted()
    let sources = Array(Set(state.activeSourceKinds.map(\.rawValue))).sorted()

    let filter = SavedFilter(
      id: uuid().uuidString,
      name: trimmed,
      queryText: state.searchText,
      selectedTags: tags,
      selectedSources: sources,
      groupingMode: nil
    )

    state.savedFilters = sortSavedFilters(state.savedFilters + [filter])
    savedFiltersStore.save(state.savedFilters)
    state.selectedSavedFilterID = filter.id
    state.isPinnedViewActive = false
  }

  private func renameSavedFilter(id: String, newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let index = state.savedFilters.firstIndex(where: { $0.id == id }) else { return }

    let existing = state.savedFilters[index]
    let renamed = SavedFilter(
      id: existing.id,
      name: trimmed,
      queryText: existing.queryText,
      selectedTags: existing.selectedTags,
      selectedSources: existing.selectedSources,
      groupingMode: existing.groupingMode
    )
    var next = state.savedFilters
    next[index] = renamed
    state.savedFilters = sortSavedFilters(next)
    savedFiltersStore.save(state.savedFilters)
  }

  private func deleteSavedFilter(id: String) {
    state.savedFilters.removeAll { $0.id == id }
    savedFiltersStore.save(state.savedFilters)
    if state.selectedSavedFilterID == id {
      state.selectedSavedFilterID = nil
    }
  }

  private func togglePinnedPersona(id: String) {
    if state.pinnedPersonaIDs.contains(id) {
      state.pinnedPersonaIDs.remove(id)
    } else {
      state.pinnedPersonaIDs.insert(id)
    }
    pinnedPersonasStore.save(Array(state.pinnedPersonaIDs))
  }

  private func parseSourceKinds(from values: [String]) -> Set<PersonaSource.Kind> {
    Set(values.compactMap(PersonaSource.Kind.init(rawValue:)))
  }

  private func sortSavedFilters(_ filters: [SavedFilter]) -> [SavedFilter] {
    filters.sorted { lhs, rhs in
      if lhs.name != rhs.name { return lhs.name < rhs.name }
      return lhs.id < rhs.id
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

  private enum ImportCopyFailure: Error {
    case outsideRoot
  }
}
