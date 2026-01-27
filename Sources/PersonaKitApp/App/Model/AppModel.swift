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

/// The central app model coordinating state and I/O.
///
/// ``AppModel`` owns the observable UI state and coordinates I/O through
/// dependency clients to keep behaviors deterministic and testable.
@MainActor
@Observable
final class AppModel {
  var diagnostics: [Diagnostic] = []
  var personaIndex: [String: ResolvedPersona] = [:]
  var personaPacksByID: [String: PackMeta] = [:]
  var personaSourcesByID: [String: PersonaSource] = [:]
  var packLocationsByPersonaID: [String: PackLocation] = [:]
  var availablePacks: [PackSelection] = []
  var composer: ComposerModel = ComposerModel()
  var preview: PreviewModel = PreviewModel()

  @Dependency(\.fileClient)
  @ObservationIgnored var fileClient
  @Dependency(\.appClient)
  @ObservationIgnored var appClient
  @Dependency(\.uuid)
  @ObservationIgnored var uuid
  @Dependency(\.continuousClock)
  @ObservationIgnored var clock

  let sidebar: SidebarModel
  var jsonFormatTask: Task<Void, Never>?

  init(
    savedFiltersStore: SavedFiltersStore = SavedFiltersStore(),
    pinnedPersonasStore: PinnedPersonasStore = PinnedPersonasStore()
  ) {
    self.sidebar = SidebarModel(
      savedFiltersStore: savedFiltersStore,
      pinnedPersonasStore: pinnedPersonasStore
    )
  }
}
