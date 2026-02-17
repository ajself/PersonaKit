import ContextCore
import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Navigation request emitted from the sessions map to jump into another Studio panel.
struct SessionsNavigationTarget {
  let sidebarItem: SidebarItem
  let selectedLibraryItemID: String?
  let searchText: String
}

/// Sessions feature panel with list CRUD, preview/export workflows, and dependency maps.
struct SessionsPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  let onNavigate: (SessionsNavigationTarget) -> Void

  @State private var selectedSessionID: String?
  @State private var selectedTab: SessionsTab = .sessions
  @State private var sessionEditorPresentation: SessionEditorPresentation?
  @State private var pendingSessionDeletion: WorkspaceSessionListItem?
  @State private var isLoadingSessionDraft = false
  @State private var sessionActionErrorMessage: String?
  @State private var sessionPreviewActionMessage: String?

  var body: some View {
    let items = filteredSessions(workspaceStore.snapshot.sessions)
    let selectedSession = selectedSession(items: items)
    let canDeleteSelectedSession = canDeleteSelectedSession(items: items)

    return TabView(selection: $selectedTab) {
      SessionsListTabView(
        items: items,
        selectedSession: selectedSession,
        selectedSessionID: $selectedSessionID,
        sessionActionErrorMessage: sessionActionErrorMessage,
        isLoadingSessionDraft: isLoadingSessionDraft,
        canDeleteSelectedSession: canDeleteSelectedSession,
        onNewSession: {
          sessionEditorPresentation = SessionEditorPresentation(
            title: "New Session",
            originalSessionID: nil,
            draft: workspaceStore.defaultSessionDraft()
          )
        },
        onEditSession: {
          openEditorForSelectedSession(items: items)
        },
        onDeleteSession: {
          requestDeleteForSelectedSession(items: items)
        },
        onRevealInFinder: {
          guard let selectedSession else {
            return
          }

          workspaceStore.revealInFinder(fileURL: selectedSession.fileURL)
        }
      )
      .tabItem {
        Label("Sessions", systemImage: "list.bullet")
      }
      .tag(SessionsTab.sessions)

      SessionsPreviewTabView(
        selectedSession: selectedSession,
        sessionPreview: workspaceStore.sessionPreview,
        sessionPreviewErrorMessage: workspaceStore.sessionPreviewErrorMessage,
        sessionPreviewActionMessage: sessionPreviewActionMessage,
        isLoadingSessionPreview: workspaceStore.isLoadingSessionPreview,
        onRefresh: {
          refreshSelectedSessionPreview(items: items)
        },
        onRevealInFinder: {
          guard let selectedSession else {
            return
          }

          workspaceStore.revealInFinder(fileURL: selectedSession.fileURL)
        },
        onCopy: {
          copySessionPreview()
        },
        onExport: {
          exportSessionPreview()
        }
      )
      .tabItem {
        Label("Preview", systemImage: "doc.plaintext")
      }
      .tag(SessionsTab.preview)

      SessionsMapTabView(
        selectedSession: selectedSession,
        sessionMap: workspaceStore.sessionMap,
        sessionMapErrorMessage: workspaceStore.sessionMapErrorMessage,
        isLoadingSessionMap: workspaceStore.isLoadingSessionMap,
        snapshot: workspaceStore.snapshot,
        onRefresh: {
          refreshSelectedSessionMap(items: items)
        },
        onNavigateToDiagnostics: {
          onNavigate(
            SessionsNavigationTarget(
              sidebarItem: .validationResults,
              selectedLibraryItemID: nil,
              searchText: ""
            )
          )
        },
        onSelectNode: { node in
          guard
            let target = SessionsMapNavigationResolver.navigationTarget(
              for: node,
              selectedSessionID: selectedSession?.id
            )
          else {
            return
          }

          onNavigate(target)
        }
      )
      .tabItem {
        Label("Map", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
      }
      .tag(SessionsTab.map)
    }
    .searchable(text: $searchText, prompt: "Search Sessions")
    .onChange(of: selectedSessionID) { _, _ in
      refreshSelectedSessionPreview(items: items)
      refreshSelectedSessionMap(items: items)
    }
    .onChange(of: items.map(\.id)) { _, _ in
      refreshSelectedSessionPreview(items: items)
      refreshSelectedSessionMap(items: items)
    }
    .onChange(of: sessionMapRefreshToken) { _, _ in
      refreshSelectedSessionMap(items: items)
    }
    .onChange(of: selectedTab) { _, selectedTab in
      switch selectedTab {
      case .preview:
        refreshSelectedSessionPreview(items: items)

      case .map:
        refreshSelectedSessionMap(items: items)

      case .sessions:
        break
      }
    }
    .onAppear {
      refreshSelectedSessionPreview(items: items)
      refreshSelectedSessionMap(items: items)
    }
    .sheet(
      item: $sessionEditorPresentation,
      onDismiss: {
        workspaceStore.clearDraftSessionMap()
      }
    ) { presentation in
      SessionEditorView(
        title: presentation.title,
        initialDraft: presentation.draft,
        personaIDs: workspaceStore.snapshot.personas.map(\.id).sorted(),
        directiveIDs: workspaceStore.snapshot.directives.map(\.id).sorted(),
        kitIDs: workspaceStore.snapshot.kits.map(\.id).sorted(),
        draftSessionMap: workspaceStore.draftSessionMap,
        draftSessionMapErrorMessage: workspaceStore.draftSessionMapErrorMessage,
        isLoadingDraftSessionMap: workspaceStore.isLoadingDraftSessionMap,
        scopeByNodeKey: scopeByNodeKey,
        onCancel: {
          workspaceStore.clearDraftSessionMap()
          sessionEditorPresentation = nil
        },
        onSave: { draft in
          await saveSessionDraft(
            draft,
            originalSessionID: presentation.originalSessionID
          )
        },
        onRefreshMap: { draft in
          workspaceStore.refreshDraftSessionMap(for: draft)
        },
        onSelectMapNode: { node in
          guard
            let target = SessionsMapNavigationResolver.navigationTarget(
              for: node,
              selectedSessionID: presentation.originalSessionID
            )
          else {
            return
          }

          onNavigate(target)
        }
      )
    }
    .alert(
      "Delete Session?",
      isPresented: Binding(
        get: {
          pendingSessionDeletion != nil
        },
        set: { isPresented in
          if !isPresented {
            pendingSessionDeletion = nil
          }
        }
      ),
      presenting: pendingSessionDeletion
    ) { session in
      Button("Delete", role: .destructive) {
        deleteSession(session)
      }

      Button("Cancel", role: .cancel) {
        pendingSessionDeletion = nil
      }
    } message: { session in
      Text("Delete session \"\(session.id)\" from project scope?")
    }
  }

  private var scopeByNodeKey: [String: WorkspaceSourceScope] {
    var scopes: [String: WorkspaceSourceScope] = [:]

    for session in workspaceStore.snapshot.sessions {
      scopes["session:\(session.id)"] = session.sourceScope
    }

    for persona in workspaceStore.snapshot.personas {
      scopes["persona:\(persona.id)"] = persona.sourceScope
    }

    for directive in workspaceStore.snapshot.directives {
      scopes["directive:\(directive.id)"] = directive.sourceScope
    }

    for kit in workspaceStore.snapshot.kits {
      scopes["kit:\(kit.id)"] = kit.sourceScope
    }

    for intent in workspaceStore.snapshot.intents {
      scopes["intent:\(intent.id)"] = intent.sourceScope
    }

    for skill in workspaceStore.snapshot.skills {
      scopes["skill:\(skill.id)"] = skill.sourceScope
    }

    for essential in workspaceStore.snapshot.essentials {
      scopes["essential:\(essential.id)"] = essential.sourceScope
    }

    return scopes
  }

  private var sessionMapRefreshToken: String {
    let snapshot = workspaceStore.snapshot

    let sessionToken = snapshot.sessions
      .map { "\($0.id)::\($0.personaId)::\($0.directiveId)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let personaToken = snapshot.personas
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let directiveToken = snapshot.directives
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let kitToken = snapshot.kits
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let intentToken = snapshot.intents
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let skillToken = snapshot.skills
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let essentialToken = snapshot.essentials
      .map { "\($0.id)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    return [
      sessionToken,
      personaToken,
      directiveToken,
      kitToken,
      intentToken,
      skillToken,
      essentialToken,
    ]
    .joined(separator: "||")
  }

  private func filteredSessions(_ items: [WorkspaceSessionListItem]) -> [WorkspaceSessionListItem] {
    let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedSearch.isEmpty else {
      return items
    }

    return items.filter { item in
      item.id.localizedCaseInsensitiveContains(normalizedSearch)
        || item.personaId.localizedCaseInsensitiveContains(normalizedSearch)
        || item.directiveId.localizedCaseInsensitiveContains(normalizedSearch)
        || item.fileURL.path().localizedCaseInsensitiveContains(normalizedSearch)
    }
  }

  private func selectedSession(
    items: [WorkspaceSessionListItem]
  ) -> WorkspaceSessionListItem? {
    guard let selectedSessionID else {
      return nil
    }

    return items.first { $0.id == selectedSessionID }
  }

  private func canDeleteSelectedSession(
    items: [WorkspaceSessionListItem]
  ) -> Bool {
    if isLoadingSessionDraft {
      return false
    }

    guard let selectedSession = selectedSession(items: items) else {
      return false
    }

    return selectedSession.sourceScope == .project
  }

  private func openEditorForSelectedSession(items: [WorkspaceSessionListItem]) {
    guard let selectedSession = selectedSession(items: items) else {
      return
    }

    isLoadingSessionDraft = true
    sessionActionErrorMessage = nil

    Task {
      do {
        let draft = try await workspaceStore.loadSessionDraft(for: selectedSession)

        await MainActor.run {
          let originalSessionID: String?
          let title: String

          if selectedSession.sourceScope == .project {
            originalSessionID = selectedSession.id
            title = "Edit Session"
          } else {
            originalSessionID = nil
            title = "Copy Session to Project"
          }

          sessionEditorPresentation = SessionEditorPresentation(
            title: title,
            originalSessionID: originalSessionID,
            draft: draft
          )
          isLoadingSessionDraft = false
        }
      } catch {
        await MainActor.run {
          sessionActionErrorMessage = error.localizedDescription
          isLoadingSessionDraft = false
        }
      }
    }
  }

  private func requestDeleteForSelectedSession(items: [WorkspaceSessionListItem]) {
    guard let selectedSession = selectedSession(items: items) else {
      return
    }

    if selectedSession.sourceScope != .project {
      sessionActionErrorMessage = "Global sessions are read-only. Create a project session to edit or delete."
      return
    }

    pendingSessionDeletion = selectedSession
    sessionActionErrorMessage = nil
  }

  private func deleteSession(_ session: WorkspaceSessionListItem) {
    pendingSessionDeletion = nil
    sessionActionErrorMessage = nil

    Task {
      do {
        try await workspaceStore.deleteSession(sessionID: session.id)

        await MainActor.run {
          if selectedSessionID == session.id {
            selectedSessionID = nil
          }
        }
      } catch {
        await MainActor.run {
          sessionActionErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func saveSessionDraft(
    _ draft: WorkspaceSessionDraft,
    originalSessionID: String?
  ) async -> String? {
    do {
      let savedSessionID = try await workspaceStore.saveSession(
        draft: draft,
        originalSessionID: originalSessionID
      )
      selectedSessionID = savedSessionID
      sessionActionErrorMessage = nil
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  private func refreshSelectedSessionPreview(
    items: [WorkspaceSessionListItem]
  ) {
    guard selectedTab == .preview else {
      return
    }

    sessionPreviewActionMessage = nil
    workspaceStore.refreshSessionPreview(
      for: selectedSession(items: items)
    )
  }

  private func refreshSelectedSessionMap(
    items: [WorkspaceSessionListItem]
  ) {
    guard selectedTab == .map else {
      return
    }

    workspaceStore.refreshSessionMap(
      for: selectedSession(items: items)
    )
  }

  private func copySessionPreview() {
    do {
      try workspaceStore.copySessionPreviewToPasteboard()
      sessionPreviewActionMessage = "Copied preview to clipboard."
    } catch {
      sessionPreviewActionMessage = error.localizedDescription
    }
  }

  private func exportSessionPreview() {
    Task {
      do {
        let didExport = try await workspaceStore.exportSessionPreviewWithSavePanel()

        await MainActor.run {
          sessionPreviewActionMessage =
            didExport
            ? "Exported preview markdown."
            : nil
        }
      } catch {
        await MainActor.run {
          sessionPreviewActionMessage = error.localizedDescription
        }
      }
    }
  }

}

private struct SessionEditorPresentation: Identifiable {
  let title: String
  let originalSessionID: String?
  let draft: WorkspaceSessionDraft

  var id: String {
    "\(title)::\(originalSessionID ?? "new")"
  }
}

private enum SessionsTab: Hashable {
  case sessions
  case preview
  case map
}
