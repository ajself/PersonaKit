import Dependencies
import Foundation
import Observation
import PersonaKitCore

/// The resolved on-disk location of a persona pack and its metadata file.
struct PackLocation: Equatable {
  let packRoot: URL
  let packFile: URL
  let isDirectoryPack: Bool
}

/// A selectable pack reference used by the UI to identify a pack by file path.
struct PackSelection: Identifiable, Hashable {
  /// Sort keys used to keep pack lists stable and human-friendly.
  struct SortKey: Comparable {
    let displayName: String
    let packID: String
    let packPath: String

    static func < (lhs: SortKey, rhs: SortKey) -> Bool {
      if lhs.displayName != rhs.displayName {
        return lhs.displayName < rhs.displayName
      }
      if lhs.packID != rhs.packID {
        return lhs.packID < rhs.packID
      }
      return lhs.packPath < rhs.packPath
    }
  }

  let id: String
  let pack: PackMeta
  let source: PersonaSource
  let packFile: URL
  let packRoot: URL
  let isDirectoryPack: Bool

  /// A human-friendly display name derived from the pack metadata.
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

  /// Builds the ``SortKey`` used to sort pack selections deterministically.
  static func sortKey(_ selection: PackSelection) -> SortKey {
    SortKey(
      displayName: selection.displayName,
      packID: selection.pack.id,
      packPath: selection.packFile.path
    )
  }
}

/// The central app state container and action dispatcher.
///
/// ``AppStore`` owns the observable UI state and coordinates I/O through
/// dependency clients to keep behaviors deterministic and testable.
@MainActor
@Observable
final class AppStore {
  /// The full mutable state backing PersonaKitApp screens.
  struct State {
    var diagnostics: [Diagnostic]
    var personaIndex: [String: ResolvedPersona]
    var personaPacksByID: [String: PackMeta]
    var personaSourcesByID: [String: PersonaSource]
    var packLocationsByPersonaID: [String: PackLocation]
    var availablePacks: [PackSelection]
    var sidebar: SidebarFeature.State
    var composer: ComposerFeature.State
    var preview: PreviewFeature.State

    init(
      diagnostics: [Diagnostic] = [],
      personaIndex: [String: ResolvedPersona] = [:],
      personaPacksByID: [String: PackMeta] = [:],
      personaSourcesByID: [String: PersonaSource] = [:],
      packLocationsByPersonaID: [String: PackLocation] = [:],
      availablePacks: [PackSelection] = [],
      sidebar: SidebarFeature.State = SidebarFeature.State(),
      composer: ComposerFeature.State = ComposerFeature.State(),
      preview: PreviewFeature.State = PreviewFeature.State()
    ) {
      self.diagnostics = diagnostics
      self.personaIndex = personaIndex
      self.personaPacksByID = personaPacksByID
      self.personaSourcesByID = personaSourcesByID
      self.packLocationsByPersonaID = packLocationsByPersonaID
      self.availablePacks = availablePacks
      self.sidebar = sidebar
      self.composer = composer
      self.preview = preview
    }
  }

  /// Actions accepted by ``AppStore.send(_:)``.
  enum Action {
    case task
    case reloadAll
    case importPack
    case revealStorageRoot
    case revealSelectedPack
    case removeSelectedPack
    case copyPromptToClipboard
    case sidebar(SidebarFeature.Action)
    case composer(ComposerFeature.Action)
    case preview(PreviewFeature.Action)
  }

  @Dependency(\.fileClient)
  @ObservationIgnored var fileClient
  @Dependency(\.appClient)
  @ObservationIgnored var appClient
  @Dependency(\.uuid)
  @ObservationIgnored var uuid
  @Dependency(\.continuousClock)
  @ObservationIgnored var clock

  let savedFiltersStore: SavedFiltersStore
  let pinnedPersonasStore: PinnedPersonasStore
  var isApplyingSavedFilter = false
  var jsonFormatTask: Task<Void, Never>?

  var state: State

  init(
    savedFiltersStore: SavedFiltersStore = SavedFiltersStore(),
    pinnedPersonasStore: PinnedPersonasStore = PinnedPersonasStore()
  ) {
    self.savedFiltersStore = savedFiltersStore
    self.pinnedPersonasStore = pinnedPersonasStore
    self.state = State()

    state.sidebar.savedFilters = savedFiltersStore.load()
    state.sidebar.selectedSavedFilterID = SidebarFeature.allPersonasFilterID
    state.sidebar.pinnedPersonaIDs = Set(pinnedPersonasStore.load())
  }

  /// Routes an action to the appropriate handler and applies deferred recompute work.
  func send(_ action: Action) {
    let handledLifecycle = handleLifecycle(action)
    if !handledLifecycle {
      switch action {
      case .sidebar(let sidebarAction):
        handleSidebar(sidebarAction)
      case .composer(let composerAction):
        handleComposer(composerAction)
      case .preview(let previewAction):
        handlePreview(previewAction)
      default:
        break
      }
    }
    handlePreviewRecomputeIfNeeded()
  }
}
