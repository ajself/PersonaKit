import Dependencies
import Foundation
import Observation
import PersonaPadCore

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
    var jsonPreview: String

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
      jsonPreview: String = "",
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
      self.jsonPreview = jsonPreview
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
    case setJSONPreview(String)
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

  @ObservationIgnored
  @Dependency(\.continuousClock) private var clock

  private let savedFiltersStore: SavedFiltersStore
  private let pinnedPersonasStore: PinnedPersonasStore
  private var isApplyingSavedFilter = false
  private var jsonFormatTask: Task<Void, Never>?

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

  func send(_ action: Action) {
    if handleLifecycle(action) { return }
    if handleFocus(action) { return }
    if handleSelection(action) { return }
    if handleFiltering(action) { return }
    if handlePinned(action) { return }
  }
}
