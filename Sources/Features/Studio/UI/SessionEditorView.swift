import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Modal editor for creating and updating session files.
struct SessionEditorView: View {
  let title: String
  let personaOptions: SessionEditorReferenceOptions
  let directiveOptions: SessionEditorReferenceOptions
  let kitIDs: [String]
  let kitTitlesByID: [String: String]
  let draftSessionMap: WorkspaceSessionMap?
  let draftSessionMapErrorMessage: String?
  let isLoadingDraftSessionMap: Bool
  let scopeByNodeKey: [String: WorkspaceSourceScope]
  let onCancel: () -> Void
  let onSave: @Sendable (WorkspaceSessionDraft) async -> String?
  let onRefreshMap: (WorkspaceSessionDraft) -> Void
  /// The map labels the session by its saved id, so typing a new id doesn't rebuild it.
  private let savedSessionID: String

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
    personas: [WorkspaceListItem],
    directives: [WorkspaceListItem],
    kits: [WorkspaceListItem],
    draftSessionMap: WorkspaceSessionMap?,
    draftSessionMapErrorMessage: String?,
    isLoadingDraftSessionMap: Bool,
    scopeByNodeKey: [String: WorkspaceSourceScope],
    onCancel: @escaping () -> Void,
    onSave: @escaping @Sendable (WorkspaceSessionDraft) async -> String?,
    onRefreshMap: @escaping (WorkspaceSessionDraft) -> Void
  ) {
    self.title = title

    let kitOptions = SessionEditorReferenceOptions(requestedID: "", loadedItems: kits)
    self.kitIDs = kitOptions.loadedIDs
    self.kitTitlesByID = kitOptions.titlesByID
    self.draftSessionMap = draftSessionMap
    self.draftSessionMapErrorMessage = draftSessionMapErrorMessage
    self.isLoadingDraftSessionMap = isLoadingDraftSessionMap
    self.scopeByNodeKey = scopeByNodeKey
    self.onCancel = onCancel
    self.onSave = onSave
    self.onRefreshMap = onRefreshMap
    self.savedSessionID = initialDraft.id

    let personaOptions = SessionEditorReferenceOptions(
      requestedID: initialDraft.personaId,
      loadedItems: personas
    )
    let directiveOptions = SessionEditorReferenceOptions(
      requestedID: initialDraft.directiveId,
      loadedItems: directives
    )
    self.personaOptions = personaOptions
    self.directiveOptions = directiveOptions

    _id = State(initialValue: initialDraft.id)
    _personaID = State(initialValue: personaOptions.initialSelection)
    _directiveID = State(initialValue: directiveOptions.initialSelection)
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
        personaOptions: personaOptions,
        directiveOptions: directiveOptions,
        kitIDs: kitIDs,
        kitTitlesByID: kitTitlesByID,
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
        Text("Map")
          .font(.headline)

        if let draftSessionMap {
          StudioBadge(
            title: miniMapSummary(for: draftSessionMap),
            tone: draftSessionMap.isFullyResolved ? .success : .warning,
            size: .regular
          )
        }
      }

      if isLoadingDraftSessionMap {
        HStack(spacing: 8) {
          ProgressView()

          Text("Refreshing map…")
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
          }
        )
        .frame(minHeight: 180)
        .background(
          RoundedRectangle(cornerRadius: StudioDesign.Radius.card)
            .fill(.quaternary.opacity(0.15))
        )
      } else {
        Text("Choose a persona and directive to render the map.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var normalizedID: String {
    id.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var validationMessage: String {
    if normalizedID.isEmpty {
      return "Session id is required."
    }

    if !isValidSessionID(normalizedID) {
      return "Use letters, numbers, hyphen, underscore, or period for session id."
    }

    if personaID == personaOptions.unloadedID {
      return "Persona \"\(personaID)\" isn't loaded. Choose a loaded persona."
    }

    if !personaOptions.isLoaded(personaID) {
      return "Choose a valid persona."
    }

    if directiveID == directiveOptions.unloadedID {
      return "Directive \"\(directiveID)\" isn't loaded. Choose a loaded directive."
    }

    if !directiveOptions.isLoaded(directiveID) {
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
    var draft = currentDraft()
    draft.id = savedSessionID

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
