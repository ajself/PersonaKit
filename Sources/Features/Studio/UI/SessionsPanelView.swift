import ContextCore
import StudioFoundation
import SwiftUI

/// Sessions feature panel with list CRUD and preview/export workflows.
struct SessionsPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
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
    }
    .searchable(text: $searchText, prompt: "Search Sessions")
    .onChange(of: selectedSessionID) { _, _ in
      refreshSelectedSessionPreview(items: items)
    }
    .onChange(of: items.map(\.id)) { _, _ in
      refreshSelectedSessionPreview(items: items)
    }
    .onChange(of: selectedTab) { _, selectedTab in
      if selectedTab == .preview {
        refreshSelectedSessionPreview(items: items)
      }
    }
    .onAppear {
      refreshSelectedSessionPreview(items: items)
    }
    .sheet(item: $sessionEditorPresentation) { presentation in
      SessionEditorView(
        title: presentation.title,
        initialDraft: presentation.draft,
        personaIDs: workspaceStore.snapshot.personas.map(\.id).sorted(),
        directiveIDs: workspaceStore.snapshot.directives.map(\.id).sorted(),
        kitIDs: workspaceStore.snapshot.kits.map(\.id).sorted(),
        onCancel: {
          sessionEditorPresentation = nil
        },
        onSave: { draft in
          await saveSessionDraft(
            draft,
            originalSessionID: presentation.originalSessionID
          )
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
}
