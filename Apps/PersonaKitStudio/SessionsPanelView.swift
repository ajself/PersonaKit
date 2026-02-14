import PersonaKitCore
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

    return TabView(selection: $selectedTab) {
      sessionsListTab(items: items)
        .tabItem {
          Label("Sessions", systemImage: "list.bullet")
        }
        .tag(SessionsTab.sessions)

      sessionsPreviewTab(items: items)
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

  private func sessionsListTab(
    items: [WorkspaceSessionListItem]
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Button("New Session") {
          sessionEditorPresentation = SessionEditorPresentation(
            title: "New Session",
            originalSessionID: nil,
            draft: workspaceStore.defaultSessionDraft()
          )
        }

        Button("Edit Session") {
          openEditorForSelectedSession(items: items)
        }
        .disabled(selectedSession(items: items) == nil || isLoadingSessionDraft)

        Button("Delete Session") {
          requestDeleteForSelectedSession(items: items)
        }
        .disabled(!canDeleteSelectedSession(items: items))

        if isLoadingSessionDraft {
          ProgressView()
            .controlSize(.small)
        }

        Spacer()
      }

      if let sessionActionErrorMessage {
        Text(sessionActionErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      List(items, id: \.id, selection: $selectedSessionID) { session in
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(session.id)
              .font(.headline)

            Spacer()

            scopeBadge(scope: session.sourceScope)
          }

          Text("persona: \(session.personaId) · directive: \(session.directiveId)")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text(session.fileURL.path())
            .font(.caption.monospaced())
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .tag(Optional(session.id))
      }
      .overlay {
        if items.isEmpty {
          ContentUnavailableView.search
        }
      }
    }
  }

  private func sessionsPreviewTab(
    items: [WorkspaceSessionListItem]
  ) -> some View {
    let selectedSession = selectedSession(items: items)

    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("Session Preview")
          .font(.title3)
          .fontWeight(.semibold)

        if let selectedSession {
          Text("· \(selectedSession.id)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Refresh") {
          refreshSelectedSessionPreview(items: items)
        }
        .disabled(selectedSession == nil || workspaceStore.isLoadingSessionPreview)

        Button("Copy") {
          copySessionPreview()
        }
        .disabled(workspaceStore.sessionPreview.isEmpty || workspaceStore.isLoadingSessionPreview)

        Button("Export Markdown…") {
          exportSessionPreview()
        }
        .disabled(workspaceStore.sessionPreview.isEmpty || workspaceStore.isLoadingSessionPreview)
      }

      if let sessionPreviewActionMessage {
        Text(sessionPreviewActionMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if selectedSession == nil {
        ContentUnavailableView(
          "No Session Selected",
          systemImage: "doc.text.magnifyingglass",
          description: Text("Select a session to generate a preview.")
        )
      } else if workspaceStore.isLoadingSessionPreview {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()
          Text("Loading preview...")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let sessionPreviewErrorMessage = workspaceStore.sessionPreviewErrorMessage {
        ContentUnavailableView(
          "Preview Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(sessionPreviewErrorMessage)
        )
      } else if workspaceStore.sessionPreview.isEmpty {
        ContentUnavailableView(
          "No Preview",
          systemImage: "doc.plaintext",
          description: Text("Generate a preview for the selected session.")
        )
      } else {
        ScrollView {
          Text(workspaceStore.sessionPreview)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(12)
        }
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(0.2))
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
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

  private func scopeBadge(scope: WorkspaceSourceScope) -> some View {
    Text(scope.displayName)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(scope == .project ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
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
