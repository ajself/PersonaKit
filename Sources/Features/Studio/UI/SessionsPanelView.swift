import ContextCore
import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Sessions feature panel with list CRUD, preview/export workflows, and dependency maps.
struct SessionsPanelView: View {
  private static let listPaneMinWidth: CGFloat = 160

  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  @Binding var selectedSessionID: String?
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigate: (StudioNavigationTarget) -> Void
  let onNavigateHelpLink: (StudioHelpLink) -> Void

  @State private var detailMode = SessionsDetailMode.preview
  @SceneStorage("studio.sessions.detailMode")
  private var persistedDetailModeRawValue = SessionsDetailMode.preview.rawValue

  var body: some View {
    let sessions = workspaceStore.snapshot.sessions
    let items = SessionsListRowState.filteredSessions(
      sessions,
      searchText: searchText,
      in: workspaceStore.snapshot
    )
    let availableSessionIDs = sessions.map(\.id).sorted()
    let selectedSession = currentSelectedSession()
    let listActionState = SessionsActionState(
      selectedSession: selectedSession,
      isLoadingSessionDraft: workspaceStore.isLoadingSessionDraft
    )

    return HSplitView {
      SessionsListTabView(
        items: items,
        snapshot: workspaceStore.snapshot,
        searchText: $searchText,
        selectedSessionID: $selectedSessionID,
        sessionActionErrorMessage: workspaceStore.sessionActionErrorMessage,
        actionState: listActionState,
        onNewSession: {
          workspaceStore.presentNewSessionEditor()
        }
      )
      .frame(minWidth: Self.listPaneMinWidth, idealWidth: 250, maxWidth: .infinity)

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
    // An HSplitView behaves as if its minimum width is its current width; beside the inspector that
    // ratchets the window wider on every section switch, so pin the minimum to the list pane's.
    .frame(minWidth: Self.listPaneMinWidth, maxWidth: .infinity, maxHeight: .infinity)
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: StudioHelpTopicID.sessions),
        mode: $inspectorMode,
        onNavigateHelpLink: onNavigateHelpLink
      ) {
        SessionsInspectorView(
          selectedSession: selectedSession,
          snapshot: workspaceStore.snapshot,
          workspaceURL: workspaceStore.workspaceURL,
          mapStatusText: inspectorMapStatusText
        )
      }
      .inspectorColumnWidth(min: 180, ideal: 250, max: 340)
    }
    .onChange(of: selectedSessionID) { _, _ in
      workspaceStore.sessionSelectionDidChange()
      refreshSelectedSessionPreview()

      if detailMode == .map {
        refreshSelectedSessionMap()
      }
    }
    .onChange(of: availableSessionIDs) { _, availableSessionIDs in
      // The store revalidates the preview and map after each reload; the panel only keeps
      // its selection valid. A changed selection refreshes through `selectedSessionID`.
      selectedSessionID = SessionsPanelLayoutState.reconciledSelection(
        currentSelectedSessionID: selectedSessionID,
        availableSessionIDs: availableSessionIDs
      )
    }
    .task(id: detailMode) {
      // Let the mode switch render before starting the other mode's load.
      await Task.yield()

      guard !Task.isCancelled else {
        return
      }

      performDetailModeTransition(for: detailMode)
    }
    .onAppear {
      // The `.task(id: detailMode)` above performs the first load for the resolved mode.
      detailMode = SessionsPanelLayoutState.resolvedDetailMode(
        persistedRawValue: persistedDetailModeRawValue
      )
    }
    .sheet(
      item: Binding(
        get: {
          workspaceStore.sessionEditorPresentation
        },
        set: { presentation in
          if presentation == nil {
            workspaceStore.dismissSessionEditor()
          }
        }
      ),
      onDismiss: {
        workspaceStore.clearDraftSessionMap()
      }
    ) { presentation in
      SessionEditorView(
        title: presentation.title,
        initialDraft: presentation.draft,
        personas: workspaceStore.snapshot.personas,
        directives: workspaceStore.snapshot.directives,
        kits: workspaceStore.snapshot.kits,
        draftSessionMap: workspaceStore.draftSessionMap,
        draftSessionMapErrorMessage: workspaceStore.draftSessionMapErrorMessage,
        isLoadingDraftSessionMap: workspaceStore.isLoadingDraftSessionMap,
        scopeByNodeKey: scopeByNodeKey,
        onCancel: {
          workspaceStore.dismissSessionEditor()
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
      Text(deletionConfirmationTitle),
      isPresented: Binding(
        get: {
          workspaceStore.pendingSessionDeletion != nil
        },
        set: { isPresented in
          if !isPresented {
            workspaceStore.cancelSessionDeletion()
          }
        }
      ),
      presenting: workspaceStore.pendingSessionDeletion
    ) { presentation in
      Button("Move to Trash", role: .destructive) {
        workspaceStore.confirmSessionDeletion(presentation) { deletedSessionID in
          // Clearing (rather than leaving a stale id) lets the reload select the first session.
          if selectedSessionID == deletedSessionID {
            selectedSessionID = nil
          }
        }
      }

      Button("Cancel", role: .cancel) {
        workspaceStore.cancelSessionDeletion()
      }
    }
  }

  private var deletionConfirmationTitle: String {
    guard let session = workspaceStore.pendingSessionDeletion?.session else {
      return ""
    }

    return "Move session \"\(session.id)\" to the Trash?"
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

  private var inspectorMapStatusText: String {
    let sessionMap = workspaceStore.sessionMap

    return SessionsPanelLayoutState.inspectorMapStatusText(
      detailMode: detailMode,
      isLoading: workspaceStore.isLoadingSessionMap,
      mapIsFullyResolved: sessionMap?.isFullyResolved,
      unresolvedIssueCount: sessionMap?.resolutionErrors.count,
      loadFailed: workspaceStore.sessionMapErrorMessage != nil
    )
  }

  private var detailEmptyState: some View {
    ContentUnavailableView(
      "Select a Session",
      systemImage: "doc.text.magnifyingglass",
      description: Text("See the session's handoff context or inspect its map.")
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
      StudioBadge(
        title: mapHealthText,
        tone: sessionMap.isFullyResolved ? .success : .warning,
        size: .regular
      )
    } else {
      StudioBadge(title: mapHealthText, size: .regular)
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
        isLoadingSessionPreview: workspaceStore.isLoadingSessionPreview
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
        let sessionPreviewActionMessage = workspaceStore.sessionPreviewActionMessage
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
        StudioScopeBadge(scope: selectedSession.sourceScope)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          detailTitleView(selectedSession: selectedSession)

          Spacer(minLength: 8)

          StudioScopeBadge(scope: selectedSession.sourceScope)
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
        workspaceStore.presentSessionEditor(for: selectedSession)
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
            workspaceStore.requestSessionDeletion(selectedSession)
          }
        )
      )
    }

    return actions
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
      SessionsListRowState.subtitle(for: selectedSession, in: workspaceStore.snapshot)
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
          workspaceStore.copySessionPreviewReportingResult()
        }
      ),
      StudioUtilityActionItem(
        id: "session-preview-export",
        title: "Export Handoff…",
        systemImage: "square.and.arrow.up",
        isEnabled: !workspaceStore.sessionPreview.isEmpty && !workspaceStore.isLoadingSessionPreview,
        action: {
          workspaceStore.exportSessionPreviewReportingResult()
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

    return scopes
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
      workspaceStore.clearSessionPreviewActionMessage()
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

  private func performDetailModeTransition(
    for mode: SessionsDetailMode
  ) {
    switch mode {
    case .preview:
      workspaceStore.clearSessionMap()
    case .map:
      workspaceStore.cancelSessionPreviewRefresh()
    }

    refreshDetailContent(for: mode)
  }

  private func currentSelectedSession() -> WorkspaceSessionListItem? {
    selectedSession(items: workspaceStore.snapshot.sessions)
  }
}

private struct SessionsInspectorView: View {
  let selectedSession: WorkspaceSessionListItem?
  let snapshot: WorkspaceSnapshot
  let workspaceURL: URL?
  let mapStatusText: String

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

      StudioInspectorSection("Identity") {
        StudioMetadataRow(label: "Session", value: selectedSession.id)
        StudioMetadataRow(
          label: "Persona",
          value: StudioReferenceTitle.nameFirst(id: selectedSession.personaId, in: snapshot.personas)
        )
        StudioMetadataRow(
          label: "Directive",
          value: StudioReferenceTitle.nameFirst(id: selectedSession.directiveId, in: snapshot.directives)
        )
      }

      StudioInspectorSection("Source") {
        StudioMetadataRow(label: "Scope", value: selectedSession.sourceScope.displayName)
        StudioMetadataRow(
          label: "Path",
          value: relativePath(for: selectedSession),
          monospaced: true
        )
      }

      StudioInspectorSection("Map") {
        StudioMetadataRow(label: "Status", value: mapStatusText)
      }
    }
    .accessibilityElement(children: .contain)
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
