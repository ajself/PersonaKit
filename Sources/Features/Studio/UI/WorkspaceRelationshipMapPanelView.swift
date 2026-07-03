import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Workspace-wide relationship map panel with filtering, session focus mode, and node inspection.
struct WorkspaceRelationshipMapPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigate: (StudioNavigationTarget) -> Void
  let onNavigateHelpLink: (StudioHelpLink) -> Void

  @State private var selectedSessionContextID: String?
  @State private var focusModeEnabled = false
  @State private var selectedScopeFilter: RelationshipScopeFilter = .all
  @State private var selectedNodeKinds: Set<WorkspaceSessionMapNodeKind> = Set(Self.defaultNodeKinds)
  @State private var highlightedNodeKey: String?
  @State private var layoutState = RelationshipMapLayoutState()

  private static let defaultNodeKinds: [WorkspaceSessionMapNodeKind] = [
    .session,
    .persona,
    .directive,
    .kit,
    .skill,
    .essential,
    .reference,
  ]

  private let nodeKindOrder: [WorkspaceSessionMapNodeKind] = [
    .session,
    .persona,
    .directive,
    .kit,
    .skill,
    .essential,
    .reference,
  ]

  var body: some View {
    let filteredMap = filteredWorkspaceMap()
    let selectedNode = selectedNode(in: filteredMap)
    let filteredMapNodeKeysToken = nodeKeysToken(for: filteredMap)

    // Root as a ScrollView so content insets below the window toolbar — a plain VStack
    // detail underlaps the unified toolbar and hides the header (see StudioDiagnosticsPanelView).
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        headerView

        filterControls

        if workspaceStore.isLoadingWorkspaceRelationshipMap {
          loadingView
        } else if let errorMessage = workspaceStore.workspaceRelationshipMapErrorMessage {
          ContentUnavailableView(
            "Relationship Map Failed",
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage)
          )
        } else if let focusUnavailableState = focusedMapUnavailableState {
          ContentUnavailableView(
            focusUnavailableState.title,
            systemImage: focusUnavailableState.systemImage,
            description: Text(focusUnavailableState.description)
          )
        } else if let filteredMap {
          mapView(filteredMap)
        } else {
          ContentUnavailableView(
            "No Relationship Map",
            systemImage: "point.3.filled.connected.trianglepath.dotted",
            description: Text("Load a workspace to inspect cross-entity relationships.")
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding()
    }
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: SidebarItem.relationshipMap),
        mode: $inspectorMode,
        onNavigateHelpLink: onNavigateHelpLink
      ) {
        RelationshipMapContextInspectorView(
          workspaceMap: workspaceStore.workspaceRelationshipMap,
          filteredMap: filteredMap,
          isLoading: workspaceStore.isLoadingWorkspaceRelationshipMap,
          focusModeEnabled: focusModeEnabled,
          selectedSessionID: selectedSessionContextID,
          selectedScopeTitle: selectedScopeFilter.title,
          selectedNodeKindTitles: selectedNodeKinds.map(\.menuTitle).sorted(),
          selectedNode: selectedNode,
          selectedNodeScope: selectedNode.flatMap { scopeByNodeKey[$0.key] },
          selectedNodeRelationships: selectedNodeRelationships(
            in: workspaceStore.workspaceRelationshipMap,
            selectedNode: selectedNode
          ),
          selectedNodeIssueDescriptions: selectedNodeIssueDescriptions(
            in: workspaceStore.workspaceRelationshipMap,
            selectedNode: selectedNode
          ),
          selectedNodeCanOpen: selectedNodeCanOpen(selectedNode),
          onOpenSelectedNode: {
            openSelectedNode(selectedNode)
          }
        )
      }
      .inspectorColumnWidth(min: 190, ideal: 270, max: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      workspaceStore.refreshWorkspaceRelationshipMap()
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: snapshotRefreshToken) { _, _ in
      workspaceStore.refreshWorkspaceRelationshipMap()
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: filteredMapNodeKeysToken) { _, _ in
      pruneLayoutOffsets(in: filteredWorkspaceMap())
    }
    .onChange(of: workspaceIdentityToken) { _, _ in
      selectedSessionContextID = nil
      highlightedNodeKey = nil
      layoutState.reset()
      workspaceStore.refreshWorkspaceRelationshipMap()
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: selectedSessionContextID) { _, _ in
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: focusModeEnabled) { _, _ in
      refreshFocusSessionMapIfNeeded()
    }
  }

  private var headerView: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        headerTitleGroup

        Spacer(minLength: 12)

        headerActionGroup
      }

      VStack(alignment: .leading, spacing: 8) {
        headerTitleGroup
        headerActionGroup
      }
    }
  }

  private var headerTitleGroup: some View {
    HStack(spacing: 8) {
      Text("Relationship Map")
        .font(.title3)
        .fontWeight(.semibold)

      if let workspaceMap = workspaceStore.workspaceRelationshipMap {
        Text(healthSummary(for: workspaceMap))
          .font(.caption)
          .fontWeight(.semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(workspaceMap.isFullyResolved ? .green.opacity(0.16) : .orange.opacity(0.16))
          )
          .foregroundStyle(workspaceMap.isFullyResolved ? .green : .orange)
      }
    }
  }

  private var headerActionGroup: some View {
    HStack(spacing: 8) {
      StudioSearchField(
        text: $searchText,
        prompt: "Search Relationship Map",
        accessibilityIdentifier: RelationshipMapAutomationIdentifier.searchField
      )
      .frame(minWidth: 180, idealWidth: 240, maxWidth: 280)

      StudioUtilityActionRowView(
        primaryAction: refreshUtilityAction,
        secondaryActions: secondaryHeaderActions
      )
    }
  }

  private var refreshUtilityAction: StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: RelationshipMapAutomationIdentifier.refresh,
      title: "Refresh",
      systemImage: "arrow.clockwise",
      isEnabled: workspaceStore.workspaceURL != nil && !workspaceStore.isLoadingWorkspaceRelationshipMap,
      action: {
        workspaceStore.refreshWorkspaceRelationshipMap()
        refreshFocusSessionMapIfNeeded()
      }
    )
  }

  private var secondaryHeaderActions: [StudioUtilityActionItem] {
    guard layoutState.hasManualOffsets else {
      return []
    }

    return [resetLayoutUtilityAction]
  }

  private var resetLayoutUtilityAction: StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: RelationshipMapAutomationIdentifier.resetLayout,
      title: "Reset Layout",
      systemImage: "arrow.uturn.backward",
      isEnabled: layoutState.hasManualOffsets,
      action: {
        layoutState.reset()
      }
    )
  }

  private var filterControls: some View {
    ViewThatFits(in: .horizontal) {
      filterControlRow

      VStack(alignment: .leading, spacing: 8) {
        focusControls
        filterSecondaryControls
      }
    }
  }

  private var filterControlRow: some View {
    HStack(spacing: 12) {
      focusControls
      filterSecondaryControls
      Spacer()
    }
  }

  private var filterSecondaryControls: some View {
    HStack(spacing: 12) {
      Picker("Scope", selection: $selectedScopeFilter) {
        ForEach(RelationshipScopeFilter.allCases, id: \.self) { filter in
          Text(filter.title)
            .tag(filter)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(minWidth: 180, idealWidth: 220, maxWidth: 240)

      Menu("Entity Types") {
        ForEach(nodeKindOrder, id: \.rawValue) { kind in
          Toggle(isOn: bindingForNodeKind(kind)) {
            Text(kind.menuTitle)
          }
        }
      }
    }
  }

  private var focusControls: some View {
    HStack(spacing: 12) {
      Toggle("Focus Selected Session", isOn: $focusModeEnabled)
        .toggleStyle(.checkbox)
        .disabled(workspaceStore.snapshot.sessions.isEmpty)
        .accessibilityIdentifier(RelationshipMapAutomationIdentifier.focusSelectedSession)

      Picker("Session", selection: $selectedSessionContextID) {
        Text("None")
          .tag(Optional<String>.none)

        ForEach(workspaceStore.snapshot.sessions.map(\.id).sorted(), id: \.self) { sessionID in
          Text(sessionID)
            .tag(Optional(sessionID))
        }
      }
      .labelsHidden()
      .frame(minWidth: 160, idealWidth: 200, maxWidth: 220)
      .disabled(!focusModeEnabled || workspaceStore.snapshot.sessions.isEmpty)
    }
  }

  private var loadingView: some View {
    VStack(spacing: 10) {
      ProgressView()

      Text("Loading relationship map...")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func mapView(_ filteredMap: WorkspaceSessionMap) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      SessionDependencyMapView(
        map: filteredMap,
        scopeByNodeKey: scopeByNodeKey,
        highlightedNodeKey: highlightedNodeKey,
        compact: false,
        allowsNodeDragging: true,
        nodeOffsetsByKey: Binding(
          get: {
            layoutState.nodeOffsetsByKey
          },
          set: { updatedOffsets in
            layoutState = RelationshipMapLayoutState(
              nodeOffsetsByKey: updatedOffsets
            )
          }
        ),
        showsSessionLane: true,
        showsEmptyLanes: false,
        onSelectNode: { node in
          highlightedNodeKey = node.key
        }
      )
      .frame(minHeight: 360)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(.quaternary.opacity(0.18))
      )

      relationshipReasonsView(filteredMap)

      if !filteredMap.resolutionErrors.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Relationship Issues")
            .font(.headline)

          ForEach(Array(filteredMap.resolutionErrors.enumerated()), id: \.offset) { _, issue in
            HStack(alignment: .top, spacing: 10) {
              Text(issueDescription(issue))
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)

              if let nodeKey = nodeKey(for: issue),
                filteredMap.nodes.contains(where: { $0.key == nodeKey })
              {
                Button("Go to Node") {
                  highlightedNodeKey = nodeKey
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }

              Button("Go to Validation Results") {
                onNavigate(
                  StudioNavigationTarget(
                    sidebarItem: .validationResults,
                    searchText: ""
                  )
                )
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }
        }
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.orange.opacity(0.08))
        )
      }
    }
  }

  @ViewBuilder
  private func relationshipReasonsView(_ filteredMap: WorkspaceSessionMap) -> some View {
    let summaries = RelationshipMapPresentationState.relationshipSummaries(map: filteredMap)

    if !summaries.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text("Relationship Reasons")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(summaries, id: \.self) { summary in
              Text(summary)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  Capsule()
                    .fill(.secondary.opacity(0.12))
                )
            }
          }
        }
      }
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

    for skill in workspaceStore.snapshot.skills {
      scopes["skill:\(skill.id)"] = skill.sourceScope
    }

    for essential in workspaceStore.snapshot.essentials {
      scopes["essential:\(essential.id)"] = essential.sourceScope
    }

    for reference in workspaceStore.snapshot.references {
      scopes["reference:\(reference.id)"] = reference.sourceScope
    }

    return scopes
  }

  private var snapshotRefreshToken: String {
    let snapshot = workspaceStore.snapshot

    let sessionsToken = snapshot.sessions
      .map { "\($0.id)::\($0.personaId)::\($0.directiveId)::\($0.sourceScope.rawValue)" }
      .sorted()
      .joined(separator: "|")

    let libraryToken = [
      snapshot.personas.map { "persona:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.directives.map { "directive:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.kits.map { "kit:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.skills.map { "skill:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.essentials.map { "essential:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.references.map { "reference:\($0.id)::\($0.sourceScope.rawValue)" },
    ]
    .flatMap { $0 }
    .sorted()
    .joined(separator: "|")

    return [sessionsToken, libraryToken].joined(separator: "||")
  }

  private var workspaceIdentityToken: String? {
    workspaceStore.workspaceURL?.standardizedFileURL.path
  }

  private func nodeKeysToken(
    for map: WorkspaceSessionMap?
  ) -> String {
    map?.nodes.map(\.key).sorted().joined(separator: "|") ?? ""
  }

  private func pruneLayoutOffsets(
    in map: WorkspaceSessionMap?
  ) {
    guard let map else {
      layoutState.reset()
      return
    }

    layoutState.pruneOffsets(
      validNodeKeys: Set(map.nodes.map(\.key))
    )
  }

  private func selectedNode(
    in map: WorkspaceSessionMap?
  ) -> WorkspaceSessionMapNode? {
    guard let highlightedNodeKey else {
      return nil
    }

    return map?.nodes.first { $0.key == highlightedNodeKey }
  }

  private func selectedNodeCanOpen(
    _ node: WorkspaceSessionMapNode?
  ) -> Bool {
    guard let node else {
      return false
    }

    return SessionsMapNavigationResolver.navigationTarget(
      for: node,
      selectedSessionID: selectedSessionContextID
    ) != nil
  }

  private func openSelectedNode(
    _ node: WorkspaceSessionMapNode?
  ) {
    guard let node,
      let target = SessionsMapNavigationResolver.navigationTarget(
        for: node,
        selectedSessionID: selectedSessionContextID
      )
    else {
      return
    }

    onNavigate(target)
  }

  private func selectedNodeRelationships(
    in map: WorkspaceSessionMap?,
    selectedNode: WorkspaceSessionMapNode?
  ) -> [RelationshipMapInspectorRelationship] {
    guard let map,
      let selectedNode
    else {
      return []
    }

    let nodesByKey = Dictionary(uniqueKeysWithValues: map.nodes.map { ($0.key, $0) })

    return map.edges.compactMap { edge in
      if edge.fromKey == selectedNode.key,
        let toNode = nodesByKey[edge.toKey]
      {
        return RelationshipMapInspectorRelationship(
          id: "\(edge.fromKey)->\(edge.toKey)::\(edge.reason)",
          label: "Outgoing: \(RelationshipMapPresentationState.reasonLabel(for: edge.reason)) -> \(toNode.id)"
        )
      }

      if edge.toKey == selectedNode.key,
        let fromNode = nodesByKey[edge.fromKey]
      {
        return RelationshipMapInspectorRelationship(
          id: "\(edge.fromKey)->\(edge.toKey)::\(edge.reason)",
          label: "Incoming: \(fromNode.id) -> \(RelationshipMapPresentationState.reasonLabel(for: edge.reason))"
        )
      }

      return nil
    }
    .sorted { $0.label < $1.label }
  }

  private func selectedNodeIssueDescriptions(
    in map: WorkspaceSessionMap?,
    selectedNode: WorkspaceSessionMapNode?
  ) -> [String] {
    guard let map,
      let selectedNode
    else {
      return []
    }

    return map.resolutionErrors.compactMap { issue in
      guard nodeKey(for: issue) == selectedNode.key else {
        return nil
      }

      return issueDescription(issue)
    }
    .sorted()
  }

  private func filteredWorkspaceMap() -> WorkspaceSessionMap? {
    guard let workspaceMap = workspaceStore.workspaceRelationshipMap else {
      return nil
    }

    var nodes = workspaceMap.nodes

    nodes = nodes.filter { selectedNodeKinds.contains($0.kind) }

    if selectedScopeFilter != .all {
      nodes = nodes.filter { node in
        guard let nodeScope = scopeByNodeKey[node.key] else {
          return false
        }

        switch selectedScopeFilter {
        case .all:
          return true
        case .project:
          return nodeScope == .project
        case .global:
          return nodeScope == .global
        }
      }
    }

    let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    if !normalizedSearch.isEmpty {
      nodes = nodes.filter { node in
        node.id.localizedCaseInsensitiveContains(normalizedSearch)
          || node.displayName.localizedCaseInsensitiveContains(normalizedSearch)
      }
    }

    if focusModeEnabled,
      let selectedSession = selectedSessionContext(),
      workspaceStore.sessionMapRequestKey == sessionMapRequestKey(for: selectedSession),
      let focusMap = workspaceStore.sessionMap
    {
      let focusNodeKeys = Set(focusMap.nodes.map(\.key)).union(["session:\(selectedSession.id)"])
      nodes = nodes.filter { focusNodeKeys.contains($0.key) }
    }

    let nodeKeys = Set(nodes.map(\.key))

    let edges = workspaceMap.edges.filter { edge in
      nodeKeys.contains(edge.fromKey) && nodeKeys.contains(edge.toKey)
    }

    let resolutionErrors = workspaceMap.resolutionErrors.filter { issue in
      guard let issueNodeKey = nodeKey(for: issue) else {
        return true
      }

      return nodeKeys.contains(issueNodeKey)
    }

    return WorkspaceSessionMap(
      nodes: nodes,
      edges: edges,
      resolutionErrors: resolutionErrors,
      isFullyResolved: resolutionErrors.isEmpty
    )
  }

  private var focusedMapUnavailableState: FocusedMapUnavailableState? {
    guard focusModeEnabled else {
      return nil
    }

    guard let selectedSession = selectedSessionContext() else {
      return FocusedMapUnavailableState(
        title: "Select a Session",
        systemImage: "sidebar.leading",
        description: "Choose a session to focus the relationship map."
      )
    }

    guard workspaceStore.sessionMapRequestKey == sessionMapRequestKey(for: selectedSession) else {
      return .loading
    }

    if workspaceStore.isLoadingSessionMap {
      return .loading
    }

    if let sessionMapErrorMessage = workspaceStore.sessionMapErrorMessage {
      return FocusedMapUnavailableState(
        title: "Focused Map Failed",
        systemImage: "exclamationmark.triangle",
        description: sessionMapErrorMessage
      )
    }

    guard workspaceStore.sessionMap != nil else {
      return .loading
    }

    return nil
  }

  private func sessionMapRequestKey(
    for session: WorkspaceSessionListItem
  ) -> String {
    "session:\(session.id)"
  }

  private func refreshFocusSessionMapIfNeeded() {
    guard focusModeEnabled else {
      return
    }

    guard let selectedSession = selectedSessionContext() else {
      return
    }

    workspaceStore.refreshSessionMap(for: selectedSession)
  }

  private func selectedSessionContext() -> WorkspaceSessionListItem? {
    guard let selectedSessionContextID else {
      return nil
    }

    return workspaceStore.snapshot.sessions.first { $0.id == selectedSessionContextID }
  }

  private func healthSummary(for map: WorkspaceSessionMap) -> String {
    if map.isFullyResolved {
      return "Resolved"
    }

    return "\(map.resolutionErrors.count) issue\(map.resolutionErrors.count == 1 ? "" : "s")"
  }

  private func issueDescription(_ issue: ResolverError) -> String {
    switch issue {
    case .missingPersona(let field, let id):
      return "Session \(field) references missing persona \"\(id)\"."
    case .missingDirective(let field, let id):
      return "Session \(field) references missing directive \"\(id)\"."
    case .missingKitId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing kit \"\(missingId)\"."
    case .missingSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing skill \"\(missingId)\"."
    case .conflictingPersonaSkillId(let sourceId, _, let missingId):
      return "persona \(sourceId) lists skill \"\(missingId)\" in both allowed and forbidden sets."
    case .conflictingPersonaSkillCapability(let sourceId, _, let skillId, let capability):
      return "persona \(sourceId) authorizes skill \"\(skillId)\" with forbidden capability \"\(capability)\"."
    case .unauthorizedSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) requires unauthorized skill \"\(missingId)\"."
    case .invalidSession(let sourceId, _, let message):
      return "Session \(sourceId) could not be loaded: \(message)"
    case .missingEssentialFile(let sourceType, let sourceId, let field, let missingId, _):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing essential \"\(missingId)\"."
    case .missingReferenceId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing reference \"\(missingId)\"."
    }
  }

  private func nodeKey(for issue: ResolverError) -> String? {
    switch issue {
    case .missingPersona(_, let id):
      return "persona:\(id)"
    case .missingDirective(_, let id):
      return "directive:\(id)"
    case .missingKitId(_, _, _, let missingID):
      return "kit:\(missingID)"
    case .missingSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
    case .conflictingPersonaSkillId(let sourceId, _, _):
      return "persona:\(sourceId)"
    case .conflictingPersonaSkillCapability(let sourceId, _, _, _):
      return "persona:\(sourceId)"
    case .unauthorizedSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
    case .invalidSession:
      return nil
    case .missingEssentialFile(_, _, _, let missingID, _):
      return "essential:\(missingID)"
    case .missingReferenceId(_, _, _, let missingID):
      return "reference:\(missingID)"
    }
  }

  private func bindingForNodeKind(_ kind: WorkspaceSessionMapNodeKind) -> Binding<Bool> {
    Binding(
      get: {
        selectedNodeKinds.contains(kind)
      },
      set: { isSelected in
        if isSelected {
          selectedNodeKinds.insert(kind)
        } else if selectedNodeKinds.count > 1 {
          selectedNodeKinds.remove(kind)
        }
      }
    )
  }
}

private struct RelationshipMapContextInspectorView: View {
  let workspaceMap: WorkspaceSessionMap?
  let filteredMap: WorkspaceSessionMap?
  let isLoading: Bool
  let focusModeEnabled: Bool
  let selectedSessionID: String?
  let selectedScopeTitle: String
  let selectedNodeKindTitles: [String]
  let selectedNode: WorkspaceSessionMapNode?
  let selectedNodeScope: WorkspaceSourceScope?
  let selectedNodeRelationships: [RelationshipMapInspectorRelationship]
  let selectedNodeIssueDescriptions: [String]
  let selectedNodeCanOpen: Bool
  let onOpenSelectedNode: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Relationship Map Context")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      inspectorSection("Health") {
        if isLoading {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)

            metadataText("Loading")
          }
        } else if let workspaceMap {
          metadataRow(label: "Workspace Map", value: healthText(for: workspaceMap))
        } else {
          metadataRow(label: "Workspace Map", value: "Not loaded")
        }

        if let filteredMap {
          metadataRow(label: "Visible Nodes", value: "\(filteredMap.nodes.count)")
          metadataRow(label: "Visible Edges", value: "\(filteredMap.edges.count)")
          metadataRow(label: "Visible Issues", value: "\(filteredMap.resolutionErrors.count)")
        }
      }

      inspectorSection("Focus") {
        metadataRow(label: "Mode", value: focusModeEnabled ? "Focused" : "Workspace")
        metadataRow(label: "Session", value: selectedSessionID ?? "None")
      }

      selectedNodeSection

      inspectorSection("Filters") {
        metadataRow(label: "Scope", value: selectedScopeTitle)
        metadataRow(
          label: "Entity Types",
          value: selectedNodeKindTitles.joined(separator: ", ")
        )
      }
    }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var selectedNodeSection: some View {
    inspectorSection("Selection") {
      if let selectedNode {
        metadataRow(label: "Kind", value: selectedNode.kind.menuTitle)
        metadataRow(label: "ID", value: selectedNode.id)

        if selectedNode.displayName != selectedNode.id {
          metadataRow(label: "Name", value: selectedNode.displayName)
        }

        metadataRow(label: "Scope", value: selectedNodeScope?.displayName ?? "Unknown")

        if !selectedNode.badges.isEmpty {
          metadataRow(label: "Badges", value: selectedNode.badges.sorted().joined(separator: ", "))
        }

        if !selectedNodeRelationships.isEmpty {
          relationshipList
        }

        if !selectedNodeIssueDescriptions.isEmpty {
          issueList
        }

        Button {
          onOpenSelectedNode()
        } label: {
          Label("Open", systemImage: "arrow.up.right.square")
        }
        .disabled(!selectedNodeCanOpen)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help(selectedNodeCanOpen ? "Open selected node" : "Selected node cannot be opened")
      } else {
        metadataText("Select a map node to inspect relationships.")
      }
    }
  }

  private var relationshipList: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Relationships")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      ForEach(selectedNodeRelationships) { relationship in
        metadataText(relationship.label)
      }
    }
  }

  private var issueList: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Issues")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      ForEach(selectedNodeIssueDescriptions, id: \.self) { issueDescription in
        metadataText(issueDescription)
      }
    }
  }

  private func healthText(
    for map: WorkspaceSessionMap
  ) -> String {
    if map.isFullyResolved {
      return "Resolved"
    }

    return "\(map.resolutionErrors.count) issue\(map.resolutionErrors.count == 1 ? "" : "s")"
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
    value: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      metadataText(value)
    }
  }

  private func metadataText(
    _ value: String
  ) -> some View {
    Text(value)
      .font(.subheadline)
      .foregroundStyle(.primary)
      .lineLimit(4)
      .truncationMode(.tail)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct RelationshipMapInspectorRelationship: Identifiable, Sendable {
  let id: String
  let label: String
}

private struct FocusedMapUnavailableState {
  let title: String
  let systemImage: String
  let description: String

  static let loading = FocusedMapUnavailableState(
    title: "Loading Focused Map",
    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
    description: "Loading the selected session map before applying focus."
  )
}

private enum RelationshipScopeFilter: CaseIterable {
  case all
  case project
  case global

  var title: String {
    switch self {
    case .all:
      return "All Scopes"
    case .project:
      return "Project"
    case .global:
      return "Global"
    }
  }
}

extension WorkspaceSessionMapNodeKind {
  fileprivate var menuTitle: String {
    switch self {
    case .session:
      return "Session"
    case .persona:
      return "Persona"
    case .directive:
      return "Directive"
    case .kit:
      return "Kit"
    case .skill:
      return "Skill"
    case .essential:
      return "Essential"
    case .reference:
      return "Reference"
    }
  }
}
