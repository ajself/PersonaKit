import Foundation
import SwiftUI
import AppKit
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

@MainActor
final class AppStore: ObservableObject {
  @Published var diagnostics: [Diagnostic] = []
  @Published var personaIndex: [String: ResolvedPersona] = [:]
  @Published var personaPacksByID: [String: PackMeta] = [:]

  @Published var selectedPersonaID: String?
  @Published var composerValues: [String: String] = [:]
  @Published var promptPreview: String = ""

  @Published var searchText: String = ""
  @Published var selectedTag: String?
  @Published var sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: UUID(), shouldFocus: false)
  @Published var isSidebarSearchFocused: Bool = false
  @Published var composerFocusRequest: ComposerFocusRequest?

  func reloadAll() {
    diagnostics.removeAll()
    let previousSelection = selectedPersonaID

    var sets: [PersonaSet] = []
    var packsByID: [String: PackMeta] = [:]

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
    let userPacks = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/PersonaPad/Packs", isDirectory: true)
    if FileManager.default.fileExists(atPath: userPacks.path) {
      let loaded = PersonaLoader.loadDocuments(in: userPacks, sourceKind: .user)
      sets.append(contentsOf: loaded.sets)
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
      }
    }

    let merged = PersonaResolver.mergeSets(sets)
    diagnostics.append(contentsOf: merged.diagnostics)

    let resolved = PersonaResolver.resolveAll(from: merged.personas)
    diagnostics.append(contentsOf: resolved.diagnostics)
    personaIndex = resolved.personasByID
    personaPacksByID = packsByID

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
}
