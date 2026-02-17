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
  @State private var detailMode = SessionsDetailMode.preview
  @State private var detailModeTransitionTask: Task<Void, Never>?
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

      if detailMode == .map {
        refreshSelectedSessionMap()
      }
    }
    .onChange(of: availableSessionIDs) { _, availableSessionIDs in
      selectedSessionID = SessionsPanelLayoutState.reconciledSelection(
        currentSelectedSessionID: selectedSessionID,
        availableSessionIDs: availableSessionIDs
      )
      refreshSelectedSessionPreview(forceReload: true)

      if detailMode == .map {
        refreshSelectedSessionMap()
      }
    }
    .onChange(of: workspaceStore.snapshotRevision) { _, _ in
      if detailMode == .map {
        refreshSelectedSessionMap()
      }
    }
    .onChange(of: detailMode) { _, _ in
      scheduleDetailModeTransition(for: detailMode)
    }
    .onAppear {
      detailMode = SessionsPanelLayoutState.resolvedDetailMode(
        persistedRawValue: persistedDetailModeRawValue
      )
      performDetailModeTransition(for: detailMode)
    }
    .onDisappear {
      detailModeTransitionTask?.cancel()
      detailModeTransitionTask = nil
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

  private var detailModeBinding: Binding<SessionsDetailMode> {
    Binding(
      get: {
        detailMode
      },
      set: { mode in
        detailMode = mode
        persistedDetailModeRawValue = SessionsPanelLayoutState.persistedRawValue(
          for: mode
        )
      }
    )
  }

  private var detailModeItems: [StudioModeSwitchItem<SessionsDetailMode>] {
    let unresolvedIssueCount = sessionFeatureModel.map?.resolutionErrors.count
    let unresolvedIssueBadgeText: String?

    if let mapRequestKey = sessionFeatureModel.mapRequestKey,
      let selectedSessionID
    {
      unresolvedIssueBadgeText = SessionsPanelLayoutState.unresolvedIssueBadgeText(
        issueCount: unresolvedIssueCount,
        mapRequestKey: mapRequestKey,
        selectedSessionID: selectedSessionID
      )
    } else {
      unresolvedIssueBadgeText = nil
    }

    return SessionsDetailMode.allCases.map { mode in
      let badgeText: String?

      if mode == .map {
        badgeText = unresolvedIssueBadgeText
      } else {
        badgeText = nil
      }

      return StudioModeSwitchItem(
        id: mode,
        title: mode.title,
        systemImage: mode.systemImage,
        badgeText: badgeText,
        accessibilityHint: mode.accessibilityHint
      )
    }
  }

  private var mapHealthText: String {
    let sessionMap = sessionFeatureModel.map

    return SessionsPanelLayoutState.mapHealthText(
      isLoading: sessionFeatureModel.isLoadingMap,
      mapIsFullyResolved: sessionMap?.isFullyResolved,
      unresolvedIssueCount: sessionMap?.resolutionErrors.count
    )
  }

  @ViewBuilder
  private var mapHealthStatusView: some View {
    if sessionFeatureModel.isLoadingMap {
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.small)

        Text(mapHealthText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else if let sessionMap = sessionFeatureModel.map {
      Text(mapHealthText)
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          Capsule()
            .fill(sessionMap.isFullyResolved ? .green.opacity(0.16) : .orange.opacity(0.16))
        )
        .foregroundStyle(sessionMap.isFullyResolved ? .green : .orange)
    } else {
      Text(mapHealthText)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          Capsule()
            .fill(.quaternary.opacity(0.16))
        )
    }
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
          Text(selectedSession.id)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.middle)

          VStack(alignment: .leading, spacing: 2) {
            Text(
              SessionsPanelLayoutState.personaMetadataLine(
                personaID: selectedSession.personaId
              )
            )
            .lineLimit(1)
            .truncationMode(.tail)

            Text(
              SessionsPanelLayoutState.directiveMetadataLine(
                directiveID: selectedSession.directiveId
              )
            )
            .lineLimit(1)
            .truncationMode(.tail)
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        Spacer()

        StudioModeSwitchView(
          items: detailModeItems,
          selection: detailModeBinding,
          keyboardShortcut: { mode in
            switch mode {
            case .preview:
              return ("1", [.command])
            case .map:
              return ("2", [.command])
            }
          }
        )
        .frame(width: 220)
      }

      switch detailMode {
      case .preview:
        HStack(spacing: 8) {
          Button("Refresh") {
            refreshSelectedSessionPreview(forceReload: true)
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
        HStack(spacing: 12) {
          HStack(spacing: 8) {
            Text("Map Health")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.secondary)

            mapHealthStatusView
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Map Health")
          .accessibilityValue(mapHealthText)

          Spacer()

          Button("Refresh") {
            refreshSelectedSessionMap(forceReload: true)
          }
          .disabled(sessionFeatureModel.isLoadingMap)
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

  private func refreshSelectedSessionPreview(
    forceReload: Bool = false
  ) {
    guard detailMode == .preview else {
      return
    }

    refreshDetailContent(
      for: .preview,
      forceReload: forceReload
    )
  }

  private func refreshSelectedSessionMap(
    forceReload: Bool = false
  ) {
    guard detailMode == .map else {
      return
    }

    refreshDetailContent(
      for: .map,
      forceReload: forceReload
    )
  }

  private func refreshDetailContent(
    for mode: SessionsDetailMode,
    forceReload: Bool = false
  ) {
    switch mode {
    case .preview:
      sessionPreviewActionMessage = nil
      workspaceStore.refreshSessionPreview(
        for: currentSelectedSession(),
        forceReload: forceReload
      )

    case .map:
      workspaceStore.refreshSessionMap(
        for: currentSelectedSession(),
        forceReload: forceReload
      )
    }
  }

  private func scheduleDetailModeTransition(
    for mode: SessionsDetailMode
  ) {
    detailModeTransitionTask?.cancel()
    detailModeTransitionTask = Task { @MainActor [mode] in
      await Task.yield()

      guard !Task.isCancelled else {
        return
      }

      performDetailModeTransition(for: mode)
    }
  }

  private func performDetailModeTransition(
    for mode: SessionsDetailMode
  ) {
    switch mode {
    case .preview:
      sessionFeatureModel.cancelMapTask()
    case .map:
      sessionFeatureModel.cancelPreviewTask()
    }

    refreshDetailContent(for: mode)
  }

  private func currentSelectedSession() -> WorkspaceSessionListItem? {
    selectedSession(items: workspaceStore.snapshot.sessions)
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
