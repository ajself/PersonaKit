import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Workspace-wide relationship map panel with filtering and session focus mode.
struct WorkspaceRelationshipMapPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  let onNavigate: (SessionsNavigationTarget) -> Void

  @SceneStorage(StudioHelpStorageKey.relationshipMap)
  private var isRelationshipMapHelpExpanded = false

  @State private var selectedSessionContextID: String?
  @State private var focusModeEnabled = false
  @State private var selectedScopeFilter: RelationshipScopeFilter = .all
  @State private var selectedNodeKinds: Set<WorkspaceSessionMapNodeKind> = Set(Self.defaultNodeKinds)
  @State private var highlightedNodeKey: String?

  private static let defaultNodeKinds: [WorkspaceSessionMapNodeKind] = [
    .persona,
    .directive,
    .kit,
    .intent,
    .skill,
    .essential,
  ]

  private let nodeKindOrder: [WorkspaceSessionMapNodeKind] = [
    .persona,
    .directive,
    .kit,
    .intent,
    .skill,
    .essential,
  ]

  var body: some View {
    let filteredMap = filteredWorkspaceMap()

    VStack(alignment: .leading, spacing: 12) {
      headerView

      if let helpTopic = StudioHelpCatalog.topic(for: SidebarItem.relationshipMap) {
        StudioInlineHelpView(
          topic: helpTopic,
          isExpanded: $isRelationshipMapHelpExpanded
        )
      }

      filterControls

      if workspaceStore.isLoadingWorkspaceRelationshipMap {
        loadingView
      } else if let errorMessage = workspaceStore.workspaceRelationshipMapErrorMessage {
        ContentUnavailableView(
          "Relationship Map Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(errorMessage)
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
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
    .searchable(text: $searchText, prompt: "Search Relationship Map")
    .onAppear {
      workspaceStore.refreshWorkspaceRelationshipMap()
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: snapshotRefreshToken) { _, _ in
      workspaceStore.refreshWorkspaceRelationshipMap()
      refreshFocusSessionMapIfNeeded()
    }
    .onChange(of: workspaceIdentityToken) { _, _ in
      selectedSessionContextID = nil
      highlightedNodeKey = nil
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

      Spacer()

      StudioUtilityActionRowView(
        primaryAction: refreshUtilityAction,
        secondaryActions: []
      )
    }
  }

  private var refreshUtilityAction: StudioUtilityActionItem {
    StudioUtilityActionItem(
      id: "relationship-map-refresh",
      title: "Refresh",
      systemImage: "arrow.clockwise",
      isEnabled: workspaceStore.workspaceURL != nil && !workspaceStore.isLoadingWorkspaceRelationshipMap,
      action: {
        workspaceStore.refreshWorkspaceRelationshipMap()
        refreshFocusSessionMapIfNeeded()
      }
    )
  }

  private var filterControls: some View {
    HStack(spacing: 12) {
      Toggle("Focus Selected Session", isOn: $focusModeEnabled)
        .toggleStyle(.checkbox)
        .disabled(workspaceStore.snapshot.sessions.isEmpty)

      Picker("Session", selection: $selectedSessionContextID) {
        Text("None")
          .tag(Optional<String>.none)

        ForEach(workspaceStore.snapshot.sessions.map(\.id).sorted(), id: \.self) { sessionID in
          Text(sessionID)
            .tag(Optional(sessionID))
        }
      }
      .labelsHidden()
      .frame(width: 220)
      .disabled(!focusModeEnabled || workspaceStore.snapshot.sessions.isEmpty)

      Picker("Scope", selection: $selectedScopeFilter) {
        ForEach(RelationshipScopeFilter.allCases, id: \.self) { filter in
          Text(filter.title)
            .tag(filter)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 240)

      Menu("Entity Types") {
        ForEach(nodeKindOrder, id: \.rawValue) { kind in
          Toggle(isOn: bindingForNodeKind(kind)) {
            Text(kind.menuTitle)
          }
        }
      }

      Spacer()
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
        onSelectNode: { node in
          highlightedNodeKey = node.key

          guard
            let target = SessionsMapNavigationResolver.navigationTarget(
              for: node,
              selectedSessionID: selectedSessionContextID
            )
          else {
            return
          }

          onNavigate(target)
        }
      )
      .frame(minHeight: 360)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(.quaternary.opacity(0.18))
      )

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

              Button("Go to Diagnostics") {
                onNavigate(
                  SessionsNavigationTarget(
                    sidebarItem: .validationResults,
                    selectedLibraryItemID: nil,
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
      snapshot.intents.map { "intent:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.skills.map { "skill:\($0.id)::\($0.sourceScope.rawValue)" },
      snapshot.essentials.map { "essential:\($0.id)::\($0.sourceScope.rawValue)" },
    ]
    .flatMap { $0 }
    .sorted()
    .joined(separator: "|")

    return [sessionsToken, libraryToken].joined(separator: "||")
  }

  private var workspaceIdentityToken: String? {
    workspaceStore.workspaceURL?.standardizedFileURL.path
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
    case .missingIntentId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing intent \"\(missingId)\"."
    case .missingSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing skill \"\(missingId)\"."
    case .conflictingPersonaSkillId(let sourceId, _, let missingId):
      return "persona \(sourceId) lists skill \"\(missingId)\" in both allowed and forbidden sets."
    case .unauthorizedSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) requires unauthorized skill \"\(missingId)\"."
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
    case .missingIntentId(_, _, _, let missingID):
      return "intent:\(missingID)"
    case .missingSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
    case .conflictingPersonaSkillId(let sourceId, _, _):
      return "persona:\(sourceId)"
    case .unauthorizedSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
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
    case .intent:
      return "Intent"
    case .skill:
      return "Skill"
    case .essential:
      return "Essential"
    }
  }
}
