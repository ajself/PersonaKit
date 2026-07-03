import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryDetailModeTests {
  @Test
  func projectPersonaSupportsEditAndJSON() {
    let modes = StudioLibraryDetailModeResolver.availableModes(
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      entityType: .persona
    )

    #expect(modes == [.edit, .json])
  }

  @Test
  func globalPersonaUsesJSONOnly() {
    let modes = StudioLibraryDetailModeResolver.availableModes(
      selection: .personas,
      selectedItem: makeItem(scope: .global),
      entityType: .persona
    )

    #expect(modes == [.json])
  }

  @Test
  func projectSkillUsesEditAndJSON() {
    let modes = StudioLibraryDetailModeResolver.availableModes(
      selection: .skills,
      selectedItem: makeItem(scope: .project),
      entityType: .skill
    )

    #expect(modes == [.edit, .json])
  }

  @Test
  func invalidPersistedModeFallsBackToJSON() {
    let mode = StudioLibraryDetailModeResolver.resolvedMode(
      persistedRawValue: "nonsense",
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      entityType: .persona
    )

    #expect(mode == .json)
  }

  @Test
  func nilPersistedModeDefaultsEditableProjectItemToEdit() {
    let mode = StudioLibraryDetailModeResolver.preferredMode(
      persistedRawValue: nil,
    )

    #expect(mode == .edit)
  }

  @Test
  func unavailableEditPreferenceDisplaysJSONWithoutChangingPreference() {
    let preferredMode = StudioLibraryDetailMode.edit
    let effectiveMode = StudioLibraryDetailModeResolver.effectiveMode(
      preferredMode: preferredMode,
      selection: .personas,
      selectedItem: makeItem(scope: .global),
      entityType: .persona
    )

    #expect(effectiveMode == .json)
    #expect(preferredMode == .edit)
  }

  @Test
  func legacyPersistedFormResolvesToEditWhenAvailable() {
    let mode = StudioLibraryDetailModeResolver.resolvedMode(
      persistedRawValue: "form",
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      entityType: .persona
    )

    #expect(mode == .edit)
  }

  @Test
  func uninitializedInlineFormDraftIsNotDirty() {
    let isDirty = StudioLibraryInlineFormDraftStateResolver.isDirty(
      effectiveMode: .edit,
      draftPreviewRequestID: nil,
      previewRequestID: "personas::solo-developer::1",
      draftRawJSON: "",
      previewText: #"{"id":"solo-developer"}"#
    )

    #expect(!isDirty)
  }

  @Test
  func staleInlineFormDraftIsNotDirtyForCurrentPreview() {
    let isDirty = StudioLibraryInlineFormDraftStateResolver.isDirty(
      effectiveMode: .edit,
      draftPreviewRequestID: "personas::solo-developer::1",
      previewRequestID: "personas::solo-developer::2",
      draftRawJSON: "",
      previewText: #"{"id":"solo-developer"}"#
    )

    #expect(!isDirty)
  }

  @Test
  func initializedInlineFormDraftDetectsDirtyJSON() {
    let isDirty = StudioLibraryInlineFormDraftStateResolver.isDirty(
      effectiveMode: .edit,
      draftPreviewRequestID: "personas::solo-developer::1",
      previewRequestID: "personas::solo-developer::1",
      draftRawJSON: #"{"id":"updated"}"#,
      previewText: #"{"id":"solo-developer"}"#
    )

    #expect(isDirty)
  }

  private func makeItem(
    scope: WorkspaceSourceScope
  ) -> WorkspaceListItem {
    WorkspaceListItem(
      id: "solo-developer",
      displayName: "Solo Developer",
      fileURL: URL(
        fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo-developer.persona.json"
      ),
      sourceScope: scope
    )
  }
}
