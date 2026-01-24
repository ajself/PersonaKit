import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PersonaPadCore
import PersonaPadResources

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
final class AppStore: ObservableObject {
  @Published var diagnostics: [Diagnostic] = []
  @Published var personaIndex: [String: ResolvedPersona] = [:]
  @Published var personaPacksByID: [String: PackMeta] = [:]
  @Published var personaSourcesByID: [String: PersonaSource] = [:]
  @Published var packLocationsByPersonaID: [String: PackLocation] = [:]
  @Published var availablePacks: [PackSelection] = []

  @Published var selectedPersonaID: String?
  @Published var composerValues: [String: String] = [:]
  @Published var promptPreview: String = ""

  @Published var searchText: String = ""
  @Published var selectedTag: String?
  @Published var activeFilterTags: [String] = []
  @Published var activeSourceKinds: Set<PersonaSource.Kind> = []
  @Published var savedFilters: [SavedFilter] = []
  @Published var selectedSavedFilterID: String?
  @Published var pinnedPersonaIDs: Set<String> = []
  @Published var isPinnedViewActive: Bool = false
  @Published var sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: UUID(), shouldFocus: false)
  @Published var isSidebarSearchFocused: Bool = false
  @Published var composerFocusRequest: ComposerFocusRequest?

  private let savedFiltersStore = SavedFiltersStore()
  private let pinnedPersonasStore = PinnedPersonasStore()
  private var isApplyingSavedFilter = false

  static let allPersonasFilterID = "all-personas"

  init() {
    savedFilters = savedFiltersStore.load()
    selectedSavedFilterID = Self.allPersonasFilterID
    pinnedPersonaIDs = Set(pinnedPersonasStore.load())
  }

  var canRevealSelectedPack: Bool {
    guard let location = selectedPackLocation else { return false }
    return location.isDirectoryPack
  }

  var canRemoveSelectedPack: Bool {
    guard let location = selectedPackLocation,
          let personaID = selectedPersonaID,
          let source = personaSourcesByID[personaID] else { return false }
    return location.isDirectoryPack && source.kind == .user
  }

  func reloadAll() {
    diagnostics.removeAll()
    let previousSelection = selectedPersonaID

    var sets: [PersonaSet] = []
    var packsByID: [String: PackMeta] = [:]
    var sourcesByID: [String: PersonaSource] = [:]
    var packLocationsByID: [String: PackLocation] = [:]
    var packLocationsBySourceURL: [URL: PackLocation] = [:]

    // 1) Built-ins from resources (BuiltIn/*.json)
    let builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: PersonaPadResources.bundle)
    if builtInURLs.isEmpty {
      diagnostics.append(.warning(
        source: PersonaSource(kind: .builtIn, url: nil),
        message: "Built-in resources not found. Fix: ensure BuiltIn.pack.json is bundled in the app."
      ))
    } else {
      for url in builtInURLs {
        switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
        case .success(let set): sets.append(set)
        case .failure(let error): diagnostics.append(contentsOf: error.diagnostics)
        }
      }
    }

    // 2) User packs directory (best-effort)
    let userPacks = PersonaPadStoragePaths.standard().packs
    if FileManager.default.fileExists(atPath: userPacks.path) {
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
    }

    if sets.isEmpty {
      diagnostics.append(.warning(
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
    diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    diagnostics.append(contentsOf: resolved.diagnostics)
    personaIndex = resolved.personasByID
    personaPacksByID = packsByID
    personaSourcesByID = sourcesByID
    packLocationsByPersonaID = packLocationsByID
    availablePacks = buildPackSelections(sets: sets, packLocationsBySourceURL: packLocationsBySourceURL)

    if let previousSelection, personaIndex.keys.contains(previousSelection) {
      selectedPersonaID = previousSelection
    } else {
      selectedPersonaID = personaIndex.keys.sorted().first
    }
    recomputePreview()
  }

  func recomputePreview() {
    guard let id = selectedPersonaID, let persona = personaIndex[id]?.persona else {
      promptPreview = ""
      return
    }
    promptPreview = PersonaOutputRenderer.prompt(persona: persona, sections: composerValues)
  }

  func importPack() {
    let panel = NSOpenPanel()
    panel.title = "Import Pack"
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    panel.prompt = "Import"

    guard panel.runModal() == .OK, let selection = panel.url else { return }

    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      presentError(title: "Import Failed", message: "Could not create PersonaPad storage folders. Fix: check permissions for Application Support.")
      return
    }

    let planResult = PersonaPackImportPlan.plan(from: selection)
    switch planResult {
    case .failure(let error):
      presentError(title: "Import Failed", message: error.userFacingMessage)
      return
    case .success(let plan):
      let existingNames = existingPackDirectoryNames(in: paths.packs)
      let preferred = PersonaPadStorage.preferredPackDirectoryName(for: plan.pack)
      let folderName = PersonaPadStorage.uniquePackDirectoryName(preferred: preferred, existing: existingNames)
      let destination = paths.packs.appendingPathComponent(folderName, isDirectory: true)
      let tempFolderName = ".import_tmp_\(UUID().uuidString)"
      let tempDestination = paths.packs.appendingPathComponent(tempFolderName, isDirectory: true)

      do {
        try FileManager.default.createDirectory(at: tempDestination, withIntermediateDirectories: true)
        for file in plan.filesToCopy {
          guard let relativePath = plan.relativePath(for: file) else {
            throw ImportCopyFailure.outsideRoot
          }
          let target = tempDestination.appendingPathComponent(relativePath)
          let targetFolder = target.deletingLastPathComponent()
          try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: file, to: target)
        }
        try FileManager.default.moveItem(at: tempDestination, to: destination)
      } catch {
        try? FileManager.default.removeItem(at: tempDestination)
        if case ImportCopyFailure.outsideRoot = error {
          presentError(title: "Import Failed", message: "One or more files are outside the selected folder. Fix: ensure all pack files live under the pack folder.")
          return
        }
        presentError(title: "Import Failed", message: "Could not copy pack files. Fix: ensure the destination is writable. (\(error.localizedDescription))")
        return
      }
    }

    reloadAll()
  }

  func revealStorageRoot() {
    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      presentError(title: "Reveal Failed", message: "Could not create PersonaPad storage folders. Fix: check permissions for Application Support.")
      return
    }
    NSWorkspace.shared.open(paths.root)
  }

  func revealSelectedPack() {
    guard let location = selectedPackLocation, location.isDirectoryPack else {
      presentError(title: "Reveal Failed", message: "Selected pack is not a user pack folder.")
      return
    }
    NSWorkspace.shared.open(location.packRoot)
  }

  func removeSelectedPack() {
    guard let location = selectedPackLocation,
          let personaID = selectedPersonaID,
          let source = personaSourcesByID[personaID],
          location.isDirectoryPack,
          source.kind == .user else {
      presentError(title: "Remove Failed", message: "Only user packs stored in PersonaPad can be removed.")
      return
    }

    let alert = NSAlert()
    alert.messageText = "Remove Pack?"
    alert.informativeText = "This will delete the pack folder from disk. This action cannot be undone."
    alert.addButton(withTitle: "Remove")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else { return }

    do {
      try FileManager.default.removeItem(at: location.packRoot)
      reloadAll()
    } catch {
      presentError(title: "Remove Failed", message: "Could not delete the pack folder. Fix: check permissions. (\(error.localizedDescription))")
    }
  }

  func copyPromptToClipboard() {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(promptPreview, forType: .string)
  }

  func requestSidebarSearchFocus() {
    sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: UUID(), shouldFocus: true)
  }

  func requestSidebarSearchBlur() {
    sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: UUID(), shouldFocus: false)
  }

  func requestComposerFocus(sectionKey: String) {
    composerFocusRequest = ComposerFocusRequest(id: UUID(), sectionKey: sectionKey)
  }

  func setSearchText(_ text: String) {
    searchText = text
    if !isApplyingSavedFilter {
      selectedSavedFilterID = nil
    }
  }

  func setSelectedTag(_ tag: String?) {
    selectedTag = tag
    if let tag, !tag.isEmpty {
      activeFilterTags = [tag]
    } else {
      activeFilterTags = []
    }
    if !isApplyingSavedFilter {
      selectedSavedFilterID = nil
    }
  }

  func applyAllPersonasFilter() {
    isPinnedViewActive = false
    applySavedFilterState(
      id: Self.allPersonasFilterID,
      queryText: "",
      tags: [],
      sources: []
    )
  }

  func applySavedFilter(_ filter: SavedFilter) {
    isPinnedViewActive = false
    applySavedFilterState(
      id: filter.id,
      queryText: filter.queryText,
      tags: filter.selectedTags,
      sources: filter.selectedSources
    )
  }

  func saveCurrentFilter(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let tags = Array(Set(activeFilterTags)).sorted()
    let sources = Array(Set(activeSourceKinds.map(\.rawValue))).sorted()

    let filter = SavedFilter(
      id: UUID().uuidString,
      name: trimmed,
      queryText: searchText,
      selectedTags: tags,
      selectedSources: sources,
      groupingMode: nil
    )

    savedFilters = sortSavedFilters(savedFilters + [filter])
    savedFiltersStore.save(savedFilters)
    selectedSavedFilterID = filter.id
    isPinnedViewActive = false
  }

  func renameSavedFilter(id: String, newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let index = savedFilters.firstIndex(where: { $0.id == id }) else { return }

    let existing = savedFilters[index]
    let renamed = SavedFilter(
      id: existing.id,
      name: trimmed,
      queryText: existing.queryText,
      selectedTags: existing.selectedTags,
      selectedSources: existing.selectedSources,
      groupingMode: existing.groupingMode
    )
    var next = savedFilters
    next[index] = renamed
    savedFilters = sortSavedFilters(next)
    savedFiltersStore.save(savedFilters)
  }

  func deleteSavedFilter(id: String) {
    savedFilters.removeAll { $0.id == id }
    savedFiltersStore.save(savedFilters)
    if selectedSavedFilterID == id {
      selectedSavedFilterID = nil
    }
  }

  func setPinnedViewActive() {
    isPinnedViewActive = true
    selectedSavedFilterID = nil
  }

  func togglePinnedPersona(id: String) {
    if pinnedPersonaIDs.contains(id) {
      pinnedPersonaIDs.remove(id)
    } else {
      pinnedPersonaIDs.insert(id)
    }
    pinnedPersonasStore.save(Array(pinnedPersonaIDs))
  }

  private var selectedPackLocation: PackLocation? {
    guard let personaID = selectedPersonaID else { return nil }
    return packLocationsByPersonaID[personaID]
  }

  private func ensureStorageDirectories() throws -> PersonaPadStoragePaths {
    let paths = PersonaPadStoragePaths.standard()
    let fm = FileManager.default
    try fm.createDirectory(at: paths.packs, withIntermediateDirectories: true)
    try fm.createDirectory(at: paths.state, withIntermediateDirectories: true)
    return paths
  }

  private func existingPackDirectoryNames(in packsRoot: URL) -> Set<String> {
    guard let contents = try? FileManager.default.contentsOfDirectory(at: packsRoot, includingPropertiesForKeys: [.isDirectoryKey]) else {
      return []
    }
    return Set(contents.compactMap { url in
      let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      return isDirectory ? url.lastPathComponent : nil
    })
  }

  private func applySavedFilterState(id: String?, queryText: String, tags: [String], sources: [String]) {
    isApplyingSavedFilter = true
    selectedSavedFilterID = id
    searchText = queryText
    activeFilterTags = tags
    if tags.count == 1, let only = tags.first {
      selectedTag = only
    } else {
      selectedTag = nil
    }
    activeSourceKinds = parseSourceKinds(from: sources)
    isApplyingSavedFilter = false
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

  private func presentError(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.alertStyle = .warning
    alert.runModal()
  }

  private enum ImportCopyFailure: Error {
    case outsideRoot
  }
}
