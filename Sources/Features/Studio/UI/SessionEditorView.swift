import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Modal editor for creating and updating session files.
struct SessionEditorView: View {
  let title: String
  let personaIDs: [String]
  let directiveIDs: [String]
  let kitIDs: [String]
  let draftSessionMap: WorkspaceSessionMap?
  let draftSessionMapErrorMessage: String?
  let isLoadingDraftSessionMap: Bool
  let scopeByNodeKey: [String: WorkspaceSourceScope]
  let onCancel: () -> Void
  let onSave: @Sendable (WorkspaceSessionDraft) async -> String?
  let onRefreshMap: (WorkspaceSessionDraft) -> Void
  let onSelectMapNode: (WorkspaceSessionMapNode) -> Void

  @State private var id: String
  @State private var personaID: String
  @State private var directiveID: String
  @State private var selectedKitIDs: Set<String>
  @State private var isSaving = false
  @State private var saveErrorMessage: String?
  @State private var highlightedNodeKey: String?
  @State private var mapRefreshTask: Task<Void, Never>?

  init(
    title: String,
    initialDraft: WorkspaceSessionDraft,
    personaIDs: [String],
    directiveIDs: [String],
    kitIDs: [String],
    draftSessionMap: WorkspaceSessionMap?,
    draftSessionMapErrorMessage: String?,
    isLoadingDraftSessionMap: Bool,
    scopeByNodeKey: [String: WorkspaceSourceScope],
    onCancel: @escaping () -> Void,
    onSave: @escaping @Sendable (WorkspaceSessionDraft) async -> String?,
    onRefreshMap: @escaping (WorkspaceSessionDraft) -> Void,
    onSelectMapNode: @escaping (WorkspaceSessionMapNode) -> Void
  ) {
    self.title = title
    self.personaIDs = personaIDs
    self.directiveIDs = directiveIDs
    self.kitIDs = kitIDs
    self.draftSessionMap = draftSessionMap
    self.draftSessionMapErrorMessage = draftSessionMapErrorMessage
    self.isLoadingDraftSessionMap = isLoadingDraftSessionMap
    self.scopeByNodeKey = scopeByNodeKey
    self.onCancel = onCancel
    self.onSave = onSave
    self.onRefreshMap = onRefreshMap
    self.onSelectMapNode = onSelectMapNode

    let resolvedPersonaID = Self.resolvedSelection(
      requestedID: initialDraft.personaId,
      candidates: personaIDs
    )
    let resolvedDirectiveID = Self.resolvedSelection(
      requestedID: initialDraft.directiveId,
      candidates: directiveIDs
    )

    _id = State(initialValue: initialDraft.id)
    _personaID = State(initialValue: resolvedPersonaID)
    _directiveID = State(initialValue: resolvedDirectiveID)
    _selectedKitIDs = State(initialValue: Set(initialDraft.kitOverrides))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      SessionEditorFormSectionsView(
        id: $id,
        personaID: $personaID,
        directiveID: $directiveID,
        personaIDs: personaIDs,
        directiveIDs: directiveIDs,
        kitIDs: kitIDs,
        bindingForKitOverride: { kitID in
          bindingForKitOverride(kitID)
        }
      )

      miniMapSection

      SessionEditorFooterView(
        saveErrorMessage: saveErrorMessage,
        validationMessage: validationMessage,
        isSaving: isSaving,
        canSave: canSave,
        onCancel: onCancel,
        onSave: save
      )
    }
    .padding()
    .frame(minWidth: 600, minHeight: 620)
    .interactiveDismissDisabled(isSaving)
    .onAppear {
      scheduleMapRefresh()
    }
    .onDisappear {
      mapRefreshTask?.cancel()
      mapRefreshTask = nil
    }
    .onChange(of: personaID) { _, _ in
      scheduleMapRefresh()
    }
    .onChange(of: directiveID) { _, _ in
      scheduleMapRefresh()
    }
    .onChange(of: selectedKitIDs) { _, _ in
      scheduleMapRefresh()
    }
  }

  private var miniMapSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text("Dependency Mini-Map")
          .font(.headline)

        if let draftSessionMap {
          Text(miniMapSummary(for: draftSessionMap))
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              Capsule()
                .fill(draftSessionMap.isFullyResolved ? .green.opacity(0.16) : .orange.opacity(0.16))
            )
            .foregroundStyle(draftSessionMap.isFullyResolved ? .green : .orange)
        }
      }

      if isLoadingDraftSessionMap {
        HStack(spacing: 8) {
          ProgressView()

          Text("Refreshing map...")
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
      } else if let draftSessionMapErrorMessage {
        Text(draftSessionMapErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      } else if let draftSessionMap {
        SessionDependencyMapView(
          map: draftSessionMap,
          scopeByNodeKey: scopeByNodeKey,
          highlightedNodeKey: highlightedNodeKey,
          compact: true,
          onSelectNode: { node in
            highlightedNodeKey = node.key
            onSelectMapNode(node)
          }
        )
        .frame(minHeight: 180)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(0.15))
        )
      } else {
        Text("Choose a persona and directive to render the dependency map.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var normalizedID: String {
    id.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isPersonaValid: Bool {
    personaIDs.contains(personaID)
  }

  private var isDirectiveValid: Bool {
    directiveIDs.contains(directiveID)
  }

  private var validationMessage: String {
    if normalizedID.isEmpty {
      return "Session id is required."
    }

    if !isValidSessionID(normalizedID) {
      return "Use letters, numbers, hyphen, underscore, or period for session id."
    }

    if !isPersonaValid {
      return "Choose a valid persona."
    }

    if !isDirectiveValid {
      return "Choose a valid directive."
    }

    return ""
  }

  private var canSave: Bool {
    validationMessage.isEmpty
  }

  private func miniMapSummary(for map: WorkspaceSessionMap) -> String {
    if map.isFullyResolved {
      return "Resolved"
    }

    return "\(map.resolutionErrors.count) issue\(map.resolutionErrors.count == 1 ? "" : "s")"
  }

  private func bindingForKitOverride(_ kitID: String) -> Binding<Bool> {
    Binding(
      get: {
        selectedKitIDs.contains(kitID)
      },
      set: { isSelected in
        if isSelected {
          selectedKitIDs.insert(kitID)
        } else {
          selectedKitIDs.remove(kitID)
        }
      }
    )
  }

  private func scheduleMapRefresh() {
    mapRefreshTask?.cancel()
    let draft = currentDraft()

    mapRefreshTask = Task {
      try? await Task.sleep(for: .milliseconds(200))

      guard !Task.isCancelled else {
        return
      }

      await MainActor.run {
        onRefreshMap(draft)
      }
    }
  }

  private func currentDraft() -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: normalizedID,
      personaId: personaID,
      directiveId: directiveID,
      kitOverrides: selectedKitIDs.sorted()
    )
  }

  private func save() {
    isSaving = true
    saveErrorMessage = nil

    Task {
      let saveErrorMessage = await onSave(currentDraft())

      await MainActor.run {
        isSaving = false

        if let saveErrorMessage {
          self.saveErrorMessage = saveErrorMessage
        } else {
          onCancel()
        }
      }
    }
  }

  private static func resolvedSelection(
    requestedID: String,
    candidates: [String]
  ) -> String {
    if candidates.contains(requestedID) {
      return requestedID
    }

    return candidates.first ?? ""
  }

  private func isValidSessionID(_ value: String) -> Bool {
    let allowedCharacters = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )

    if value.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
      return false
    }

    if value.hasPrefix(".") {
      return false
    }

    return value != "." && value != ".."
  }
}
