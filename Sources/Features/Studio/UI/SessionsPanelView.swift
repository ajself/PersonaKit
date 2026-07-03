import ContextCore
import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Sessions feature panel with list CRUD, preview/export workflows, and dependency maps.
struct SessionsPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  @Binding var selectedSessionID: String?
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigate: (StudioNavigationTarget) -> Void
  let onNavigateHelpLink: (StudioHelpLink) -> Void

  @State private var detailMode = SessionsDetailMode.preview
  @State private var detailModeTransitionTask: Task<Void, Never>?
  @SceneStorage("studio.sessions.detailMode")
  private var persistedDetailModeRawValue = SessionsDetailMode.preview.rawValue
  @State private var sessionEditorPresentation: SessionEditorPresentation?
  @State private var pendingSessionDeletion: SessionDeletionPresentation?
  @State private var isLoadingSessionDraft = false
  @State private var sessionActionErrorMessage: String?
  @State private var sessionPreviewActionMessage: String?

  var body: some View {
    let sessions = workspaceStore.snapshot.sessions
    let items = filteredSessions(sessions)
    let availableSessionIDs = sessions.map(\.id).sorted()
    let selectedSession = currentSelectedSession()
    let listActionState = SessionsActionState(
      selectedSession: selectedSession,
      isLoadingSessionDraft: isLoadingSessionDraft
    )

    return HSplitView {
      SessionsListTabView(
        items: items,
        searchText: $searchText,
        selectedSessionID: $selectedSessionID,
        sessionActionErrorMessage: sessionActionErrorMessage,
        actionState: listActionState,
        onNewSession: {
          guard let workspaceURL = workspaceStore.workspaceURL?.standardizedFileURL else {
            sessionActionErrorMessage = "No workspace is currently selected."
            return
          }

          sessionEditorPresentation = SessionEditorPresentation(
            title: "New Session",
            originalSessionID: nil,
            originalSessionFileURL: nil,
            draft: workspaceStore.defaultSessionDraft(),
            workspaceURL: workspaceURL
          )
        }
      )
      .frame(minWidth: 160, idealWidth: 250, maxWidth: .infinity)

      VStack(spacing: 0) {
        if let selectedSession {
          detailHeader(
            selectedSession: selectedSession,
            actionState: listActionState
          )

          Divider()

          detailContent(selectedSession: selectedSession)
        } else {
          detailEmptyState
        }
      }
      .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: StudioHelpTopicID.sessions),
        mode: $inspectorMode,
        onNavigateHelpLink: onNavigateHelpLink
      ) {
        SessionsInspectorView(
          selectedSession: selectedSession,
          workspaceURL: workspaceStore.workspaceURL,
          relationshipStatusText: inspectorRelationshipStatusText
        )
      }
      .inspectorColumnWidth(min: 180, ideal: 250, max: 340)
    }
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
      // Reload the preview when workspace data changes (e.g. after connecting the shared
      // library) so the in-place Connect prompt resolves without re-selecting the session.
      refreshSelectedSessionPreview(forceReload: true)

      if detailMode == .map {
        refreshSelectedSessionMap()
      }
    }
    .onChange(of: detailMode) { _, _ in
      scheduleDetailModeTransition(for: detailMode)
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      clearSessionPresentations()
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
            presentation: presentation
          )
        },
        onRefreshMap: { draft in
          workspaceStore.refreshDraftSessionMap(for: draft)
        },
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
    ) { presentation in
      Button("Delete", role: .destructive) {
        deleteSession(presentation)
      }

      Button("Cancel", role: .cancel) {
        pendingSessionDeletion = nil
      }
    } message: { presentation in
      Text("Delete session \"\(presentation.session.id)\" from project scope?")
    }
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
    SessionsDetailMode.allCases.map { mode in
      StudioModeSwitchItem(
        id: mode,
        title: mode.title,
        systemImage: mode.systemImage,
        badgeText: nil,
        accessibilityHint: mode.accessibilityHint
      )
    }
  }

  private var mapHealthText: String {
    let sessionMap = workspaceStore.sessionMap

    return SessionsPanelLayoutState.mapHealthText(
      isLoading: workspaceStore.isLoadingSessionMap,
      mapIsFullyResolved: sessionMap?.isFullyResolved,
      unresolvedIssueCount: sessionMap?.resolutionErrors.count
    )
  }

  private var inspectorRelationshipStatusText: String {
    guard !workspaceStore.isLoadingSessionMap,
      workspaceStore.sessionMap == nil
    else {
      return mapHealthText
    }

    return "Not checked"
  }

  private var detailEmptyState: some View {
    ContentUnavailableView(
      "Select a Session",
      systemImage: "doc.text.magnifyingglass",
      description: Text("Preview the resolved session contract or inspect its relationship map.")
    )
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var mapHealthStatusView: some View {
    if workspaceStore.isLoadingSessionMap {
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.small)

        Text(mapHealthText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else if let sessionMap = workspaceStore.sessionMap {
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
        sessionPreview: workspaceStore.sessionPreview,
        sessionPreviewErrorMessage: workspaceStore.sessionPreviewErrorMessage,
        isLoadingSessionPreview: workspaceStore.isLoadingSessionPreview,
        isGlobalLibraryConnected: workspaceStore.isGlobalLibraryConnected,
        onConnectGlobalLibrary: {
          workspaceStore.connectGlobalLibrary()
        }
      )

    case .map:
      SessionsMapTabView(
        selectedSession: selectedSession,
        sessionMap: workspaceStore.sessionMap,
        sessionMapErrorMessage: workspaceStore.sessionMapErrorMessage,
        isLoadingSessionMap: workspaceStore.isLoadingSessionMap,
        snapshot: workspaceStore.snapshot,
        onNavigateToDiagnostics: {
          onNavigate(
            StudioNavigationTarget(
              sidebarItem: .validationResults,
              searchText: ""
            )
          )
        }
      )
    }
  }

  @ViewBuilder
  private func detailHeader(
    selectedSession: WorkspaceSessionListItem,
    actionState: SessionsActionState
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      detailTitleRow(
        selectedSession: selectedSession,
        actionState: actionState
      )

      detailMetadataRow(selectedSession: selectedSession)
      detailActionRow(selectedSession: selectedSession)

      if detailMode == .preview,
        let sessionPreviewActionMessage
      {
        Text(sessionPreviewActionMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.07))
  }

  private func detailTitleRow(
    selectedSession: WorkspaceSessionListItem,
    actionState: SessionsActionState
  ) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        detailTitleView(selectedSession: selectedSession)

        Spacer(minLength: 12)

        detailModeSwitch
        selectedSessionActionControls(
          selectedSession: selectedSession,
          actionState: actionState
        )
        detailScopeBadge(scope: selectedSession.sourceScope)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          detailTitleView(selectedSession: selectedSession)

          Spacer(minLength: 8)

          detailScopeBadge(scope: selectedSession.sourceScope)
        }

        detailModeSwitch
        selectedSessionActionControls(
          selectedSession: selectedSession,
          actionState: actionState
        )
      }
    }
  }

  private func detailTitleView(
    selectedSession: WorkspaceSessionListItem
  ) -> some View {
    Text(selectedSession.id)
      .font(.title3)
      .fontWeight(.semibold)
      .lineLimit(1)
      .truncationMode(.middle)
      .textSelection(.enabled)
  }

  private func selectedSessionActionControls(
    selectedSession: WorkspaceSessionListItem,
    actionState: SessionsActionState
  ) -> some View {
    StudioUtilityActionRowView(
      primaryAction: selectedSessionPrimaryUtilityAction(
        selectedSession: selectedSession,
        actionState: actionState
      ),
      secondaryActions: selectedSessionSecondaryUtilityActions(
        selectedSession: selectedSession,
        actionState: actionState
      ),
      visibleSecondaryActionCount: 2
    )
  }

  private func selectedSessionPrimaryUtilityAction(
    selectedSession: WorkspaceSessionListItem,
    actionState: SessionsActionState
  ) -> StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: "session-detail-edit",
      title: selectedSession.sourceScope == .project ? "Edit" : "Copy to Project",
      systemImage: selectedSession.sourceScope == .project ? "pencil" : "arrow.down.doc",
      isEnabled: actionState.canEdit,
      action: {
        openEditorForSelectedSession(selectedSession: selectedSession)
      }
    )
  }

  private func selectedSessionSecondaryUtilityActions(
    selectedSession: WorkspaceSessionListItem,
    actionState: SessionsActionState
  ) -> [StudioUtilityActionItem] {
    var actions = [
      StudioUtilityActionItem(
        id: "session-detail-reveal",
        title: "Reveal",
        systemImage: "folder",
        isEnabled: actionState.canReveal,
        action: {
          workspaceStore.revealInFinder(fileURL: selectedSession.fileURL)
        }
      )
    ]

    if selectedSession.sourceScope == .project {
      actions.append(
        StudioUtilityActionItem(
          id: "session-detail-delete",
          title: "Delete",
          systemImage: "trash",
          isEnabled: actionState.canDelete,
          action: {
            requestDeleteForSelectedSession(selectedSession: selectedSession)
          }
        )
      )
    }

    return actions
  }

  private func detailScopeBadge(scope: WorkspaceSourceScope) -> some View {
    Text(scope.displayName)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(scope == .project ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
  }

  private func detailMetadataRow(
    selectedSession: WorkspaceSessionListItem
  ) -> some View {
    Text(detailMetadataText(selectedSession: selectedSession))
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
  }

  private func detailMetadataText(
    selectedSession: WorkspaceSessionListItem
  ) -> String {
    var metadata = [
      SessionsPanelLayoutState.personaMetadataLine(
        personaID: selectedSession.personaId
      ),
      SessionsPanelLayoutState.directiveMetadataLine(
        directiveID: selectedSession.directiveId
      ),
    ]

    if let directive = selectedDirective(
      for: selectedSession.directiveId
    ),
      let workstreamID = directive.workstreamId,
      let phase = directive.workstreamPhase
    {
      metadata.append(
        SessionsPanelLayoutState.workstreamMetadataLine(
          workstreamID: workstreamID,
          phase: phase
        )
      )
    }

    return metadata.joined(separator: " · ")
  }

  private var detailModeSwitch: some View {
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
    .frame(width: 170)
  }

  @ViewBuilder
  private func detailActionRow(
    selectedSession: WorkspaceSessionListItem
  ) -> some View {
    switch detailMode {
    case .preview:
      previewActionRow()

    case .map:
      mapActionRow
    }
  }

  private var mapActionRow: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        mapHealthGroup
        Spacer()

        StudioUtilityActionRowView(
          primaryAction: mapPrimaryUtilityAction,
          secondaryActions: []
        )
      }

      VStack(alignment: .leading, spacing: 8) {
        mapHealthGroup

        StudioUtilityActionRowView(
          primaryAction: mapPrimaryUtilityAction,
          secondaryActions: []
        )
      }
    }
  }

  private var mapHealthGroup: some View {
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
  }

  private func previewActionRow() -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        previewActionControls()
        Spacer()
      }

      VStack(alignment: .leading, spacing: 8) {
        previewActionControls()
      }
    }
  }

  private func previewActionControls() -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        StudioUtilityActionRowView(
          primaryAction: previewPrimaryUtilityAction,
          secondaryActions: previewSecondaryUtilityActions
        )

        if workspaceStore.isLoadingSessionPreview {
          ProgressView()
            .controlSize(.small)
        }
      }
    }
    .scrollIndicators(.hidden)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
  }

  private var previewPrimaryUtilityAction: StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: "session-preview-refresh",
      title: "Refresh",
      systemImage: "arrow.clockwise",
      isEnabled: !workspaceStore.isLoadingSessionPreview,
      action: {
        refreshSelectedSessionPreview(forceReload: true)
      }
    )
  }

  private var previewSecondaryUtilityActions: [StudioUtilityActionItem] {
    [
      StudioUtilityActionItem(
        id: "session-preview-copy",
        title: "Copy",
        systemImage: "doc.on.doc",
        isEnabled: !workspaceStore.sessionPreview.isEmpty && !workspaceStore.isLoadingSessionPreview,
        action: {
          copySessionPreview()
        }
      ),
      StudioUtilityActionItem(
        id: "session-preview-export",
        title: "Export Markdown…",
        systemImage: "square.and.arrow.up",
        isEnabled: !workspaceStore.sessionPreview.isEmpty && !workspaceStore.isLoadingSessionPreview,
        action: {
          exportSessionPreview()
        }
      ),
    ]
  }

  private var mapPrimaryUtilityAction: StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: "session-map-refresh",
      title: "Refresh",
      systemImage: "arrow.clockwise",
      isEnabled: !workspaceStore.isLoadingSessionMap,
      action: {
        refreshSelectedSessionMap(forceReload: true)
      }
    )
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

  private func selectedDirective(
    for directiveID: String
  ) -> WorkspaceListItem? {
    workspaceStore.snapshot.directives.first { $0.id == directiveID }
  }

  private func openEditorForSelectedSession(
    selectedSession: WorkspaceSessionListItem?
  ) {
    guard let selectedSession else {
      return
    }

    guard let requestWorkspaceURL = workspaceStore.workspaceURL?.standardizedFileURL else {
      sessionActionErrorMessage = "No workspace is currently selected."
      return
    }

    isLoadingSessionDraft = true
    sessionActionErrorMessage = nil

    Task {
      do {
        let draft = try await workspaceStore.loadSessionDraft(for: selectedSession)

        await MainActor.run {
          guard workspaceStore.workspaceURL?.standardizedFileURL == requestWorkspaceURL else {
            isLoadingSessionDraft = false
            return
          }

          let originalSessionID: String?
          let originalSessionFileURL: URL?
          let title: String

          if selectedSession.sourceScope == .project {
            originalSessionID = selectedSession.id
            originalSessionFileURL = selectedSession.fileURL.standardizedFileURL
            title = "Edit Session"
          } else {
            originalSessionID = nil
            originalSessionFileURL = nil
            title = "Copy Session to Project"
          }

          sessionEditorPresentation = SessionEditorPresentation(
            title: title,
            originalSessionID: originalSessionID,
            originalSessionFileURL: originalSessionFileURL,
            draft: draft,
            workspaceURL: requestWorkspaceURL
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

    guard let workspaceURL = workspaceStore.workspaceURL?.standardizedFileURL else {
      sessionActionErrorMessage = "No workspace is currently selected."
      return
    }

    pendingSessionDeletion = SessionDeletionPresentation(
      session: selectedSession,
      workspaceURL: workspaceURL
    )
    sessionActionErrorMessage = nil
  }

  private func deleteSession(_ presentation: SessionDeletionPresentation) {
    pendingSessionDeletion = nil
    sessionActionErrorMessage = nil

    Task {
      do {
        try await workspaceStore.deleteSession(
          sessionID: presentation.session.id,
          expectedWorkspaceURL: presentation.workspaceURL,
          expectedSessionFileURL: presentation.session.fileURL
        )

        await MainActor.run {
          if selectedSessionID == presentation.session.id {
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
    presentation: SessionEditorPresentation
  ) async -> String? {
    do {
      let savedSessionID = try await workspaceStore.saveSession(
        draft: draft,
        originalSessionID: presentation.originalSessionID,
        expectedWorkspaceURL: presentation.workspaceURL,
        expectedOriginalSessionFileURL: presentation.originalSessionFileURL
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
      workspaceStore.cancelSessionMapRefresh()
    case .map:
      workspaceStore.cancelSessionPreviewRefresh()
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

  private func clearSessionPresentations() {
    sessionEditorPresentation = nil
    pendingSessionDeletion = nil
    isLoadingSessionDraft = false
    sessionActionErrorMessage = nil
    sessionPreviewActionMessage = nil
    workspaceStore.clearDraftSessionMap()
  }

}

private struct SessionsInspectorView: View {
  let selectedSession: WorkspaceSessionListItem?
  let workspaceURL: URL?
  let relationshipStatusText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let selectedSession {
        sessionContent(selectedSession)
      } else {
        ContentUnavailableView(
          "Select a Session",
          systemImage: "sidebar.trailing",
          description: Text("Inspect source metadata for the selected session.")
        )
        .frame(maxWidth: .infinity, minHeight: 220)
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func sessionContent(
    _ selectedSession: WorkspaceSessionListItem
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Session Inspector")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      inspectorSection("Identity") {
        metadataRow(label: "Session", value: selectedSession.id)
        metadataRow(label: "Persona", value: selectedSession.personaId)
        metadataRow(label: "Directive", value: selectedSession.directiveId)
      }

      inspectorSection("Source") {
        metadataRow(label: "Scope", value: selectedSession.sourceScope.displayName)
        metadataRow(
          label: "Path",
          value: relativePath(for: selectedSession),
          monospaced: true
        )
      }

      inspectorSection("Relationships") {
        metadataRow(label: "Status", value: relationshipStatusText)
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func inspectorSection<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 10) {
        content()
      }
    }
  }

  private func metadataRow(
    label: String,
    value: String,
    monospaced: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      Text(value)
        .font(monospaced ? .caption.monospaced() : .subheadline)
        .foregroundStyle(.primary)
        .lineLimit(monospaced ? 3 : 4)
        .truncationMode(monospaced ? .middle : .tail)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func relativePath(
    for selectedSession: WorkspaceSessionListItem
  ) -> String {
    guard let workspaceURL else {
      return selectedSession.fileURL.path()
    }

    let workspacePath = workspaceURL.standardizedFileURL.path()
    let filePath = selectedSession.fileURL.standardizedFileURL.path()
    let prefix = workspacePath.hasSuffix("/") ? workspacePath : "\(workspacePath)/"

    guard filePath.hasPrefix(prefix) else {
      return filePath
    }

    return String(filePath.dropFirst(prefix.count))
  }
}

private struct SessionEditorPresentation: Identifiable {
  let title: String
  let originalSessionID: String?
  let originalSessionFileURL: URL?
  let draft: WorkspaceSessionDraft
  let workspaceURL: URL

  var id: String {
    [
      workspaceURL.path(),
      title,
      originalSessionID ?? "new",
      originalSessionFileURL?.path() ?? "",
    ]
    .joined(separator: "::")
  }
}

private struct SessionDeletionPresentation: Identifiable {
  let session: WorkspaceSessionListItem
  let workspaceURL: URL

  var id: String {
    [
      workspaceURL.path(),
      session.id,
      session.fileURL.standardizedFileURL.path(),
    ]
    .joined(separator: "::")
  }
}
