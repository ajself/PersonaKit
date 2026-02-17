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
  @SceneStorage("studio.sessions.detailMode")
  private var persistedDetailModeRawValue = SessionsDetailMode.preview.rawValue
  @State private var sessionEditorPresentation: SessionEditorPresentation?
  @State private var pendingSessionDeletion: WorkspaceSessionListItem?
  @State private var isLoadingSessionDraft = false
  @State private var sessionActionErrorMessage: String?
  @State private var sessionPreviewActionMessage: String?

  var body: some View {
    let sessions = workspaceStore.snapshot.sessions
    let items = filteredSessions(sessions)
    let availableSessionIDs = sessions.map(\.id).sorted()
    let selectedSession = currentSelectedSession()
    let listActionState = SessionsListActionState(
      selectedSession: selectedSession,
      isLoadingSessionDraft: isLoadingSessionDraft
    )

    return HSplitView {
      SessionsListTabView(
        items: items,
        selectedSessionID: $selectedSessionID,
        sessionActionErrorMessage: sessionActionErrorMessage,
        actionState: listActionState,
        onNewSession: {
          sessionEditorPresentation = SessionEditorPresentation(
            title: "New Session",
            originalSessionID: nil,
            draft: workspaceStore.defaultSessionDraft()
          )
        },
        onEditSession: {
          openEditorForSelectedSession(selectedSession: selectedSession)
        },
        onDeleteSession: {
          requestDeleteForSelectedSession(selectedSession: selectedSession)
        },
        onRevealInFinder: {
          guard let selectedSession else {
            return
          }

          workspaceStore.revealInFinder(fileURL: selectedSession.fileURL)
        }
      )
      .frame(minWidth: 330, idealWidth: 390, maxWidth: 500)

      VStack(spacing: 0) {
        if let selectedSession {
          detailHeader(selectedSession: selectedSession)

          Divider()

          detailContent(selectedSession: selectedSession)
        } else {
          Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .searchable(text: $searchText, prompt: "Search Sessions")
    .onChange(of: selectedSessionID) { _, _ in
      refreshSelectedSessionPreview()
      refreshSelectedSessionMap()
    }
    .onChange(of: availableSessionIDs) { _, availableSessionIDs in
      selectedSessionID = SessionsPanelLayoutState.reconciledSelection(
        currentSelectedSessionID: selectedSessionID,
        availableSessionIDs: availableSessionIDs
      )
      refreshSelectedSessionPreview()
      refreshSelectedSessionMap()
    }
    .onChange(of: sessionMapRefreshToken) { _, _ in
      refreshSelectedSessionMap()
    }
    .onChange(of: detailMode) { _, _ in
      refreshSelectedSessionPreview()
      refreshSelectedSessionMap()
    }
    .onAppear {
      refreshSelectedSessionPreview()
      refreshSelectedSessionMap()
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

  private var sessionFeatureModel: WorkspaceSessionFeatureModel {
    workspaceStore.sessionFeatureModel
  }

  private var detailMode: SessionsDetailMode {
    SessionsPanelLayoutState.resolvedDetailMode(
      persistedRawValue: persistedDetailModeRawValue
    )
  }

  private var detailModeBinding: Binding<SessionsDetailMode> {
    Binding(
      get: {
        detailMode
      },
      set: { mode in
        persistedDetailModeRawValue = SessionsPanelLayoutState.persistedRawValue(
          for: mode
        )
      }
    )
  }

  @ViewBuilder
  private func detailContent(
    selectedSession: WorkspaceSessionListItem
  ) -> some View {
    switch detailMode {
    case .preview:
      SessionsPreviewTabView(
        sessionPreview: sessionFeatureModel.preview,
        sessionPreviewErrorMessage: sessionFeatureModel.previewErrorMessage,
        isLoadingSessionPreview: sessionFeatureModel.isLoadingPreview
      )

    case .map:
      SessionsMapTabView(
        selectedSession: selectedSession,
        sessionMap: sessionFeatureModel.map,
        sessionMapErrorMessage: sessionFeatureModel.mapErrorMessage,
        isLoadingSessionMap: sessionFeatureModel.isLoadingMap,
        snapshot: workspaceStore.snapshot,
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
              selectedSessionID: selectedSession.id
            )
          else {
            return
          }

          onNavigate(target)
        }
      )
    }
  }

  @ViewBuilder
  private func detailHeader(
    selectedSession: WorkspaceSessionListItem
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Session Detail")
            .font(.title3)
            .fontWeight(.semibold)

          Text(selectedSession.id)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Picker("Detail Mode", selection: detailModeBinding) {
          ForEach(SessionsDetailMode.allCases, id: \.self) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 190)
      }

      switch detailMode {
      case .preview:
        HStack(spacing: 8) {
          Button("Refresh") {
            refreshSelectedSessionPreview()
          }
          .disabled(sessionFeatureModel.isLoadingPreview)

          if sessionFeatureModel.isLoadingPreview {
            ProgressView()
              .controlSize(.small)
          }

          Button("Reveal in Finder") {
            workspaceStore.revealInFinder(fileURL: selectedSession.fileURL)
          }

          Button("Copy") {
            copySessionPreview()
          }
          .disabled(sessionFeatureModel.preview.isEmpty || sessionFeatureModel.isLoadingPreview)

          Button("Export Markdown…") {
            exportSessionPreview()
          }
          .disabled(sessionFeatureModel.preview.isEmpty || sessionFeatureModel.isLoadingPreview)

          Spacer()
        }

      case .map:
        HStack(spacing: 8) {
          if let sessionMap = sessionFeatureModel.map {
            Text(sessionMapHealthSummary(map: sessionMap))
              .font(.caption)
              .fontWeight(.semibold)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                Capsule()
                  .fill(sessionMap.isFullyResolved ? .green.opacity(0.16) : .orange.opacity(0.16))
              )
              .foregroundStyle(sessionMap.isFullyResolved ? .green : .orange)
          }

          Button("Refresh") {
            refreshSelectedSessionMap()
          }
          .disabled(sessionFeatureModel.isLoadingMap)

          Spacer()
        }
      }

      if detailMode == .preview,
        let sessionPreviewActionMessage
      {
        Text(sessionPreviewActionMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.07))
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

  private func openEditorForSelectedSession(
    selectedSession: WorkspaceSessionListItem?
  ) {
    guard let selectedSession else {
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

  private func requestDeleteForSelectedSession(
    selectedSession: WorkspaceSessionListItem?
  ) {
    guard let selectedSession else {
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

  private func refreshSelectedSessionPreview() {
    guard detailMode == .preview else {
      return
    }

    sessionPreviewActionMessage = nil
    workspaceStore.refreshSessionPreview(for: currentSelectedSession())
  }

  private func refreshSelectedSessionMap() {
    guard detailMode == .map else {
      return
    }

    workspaceStore.refreshSessionMap(for: currentSelectedSession())
  }

  private func currentSelectedSession() -> WorkspaceSessionListItem? {
    selectedSession(items: workspaceStore.snapshot.sessions)
  }

  private func sessionMapHealthSummary(map: WorkspaceSessionMap) -> String {
    if map.isFullyResolved {
      return "Resolved"
    }

    return "\(map.resolutionErrors.count) issue\(map.resolutionErrors.count == 1 ? "" : "s")"
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
