import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioReferenceTitleTests {
  private func item(_ id: String, _ displayName: String) -> WorkspaceListItem {
    WorkspaceListItem(
      id: id,
      displayName: displayName,
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/\(id).persona.json"),
      sourceScope: .project
    )
  }

  @Test
  func nameFirstLeadsWithTheNameAndFallsBackToTheID() {
    let items = [item("solo-developer", "Solo Developer"), item("bare", "bare")]

    #expect(StudioReferenceTitle.nameFirst(id: "solo-developer", in: items) == "Solo Developer (solo-developer)")
    #expect(StudioReferenceTitle.nameFirst(id: "bare", in: items) == "bare")
    #expect(StudioReferenceTitle.nameFirst(id: "unloaded", in: items) == "unloaded")
  }

  @Test
  func pickerOptionsAreTitledNameFirstAndOrderedByID() {
    let options = SessionEditorReferenceOptions(
      requestedID: "",
      loadedItems: [item("z-id", "Alpha Persona"), item("a-id", "Zed Persona")]
    )

    #expect(options.loadedIDs == ["a-id", "z-id"])
    #expect(options.initialSelection == "a-id")
    #expect(options.title(for: "a-id") == "Zed Persona (a-id)")
    #expect(options.title(for: "missing") == "missing")
  }

  @Test
  func usedByRowSubtitleAddsTheIDOnlyWhenTheTitleIsAName() {
    let named = WorkspaceSessionMapNode(
      key: "kit:cli-guardrails",
      id: "cli-guardrails",
      displayName: "CLI Guardrails",
      kind: .kit,
      isMissing: false,
      badges: []
    )
    let bare = WorkspaceSessionMapNode(
      key: "session:ios-bugfix",
      id: "ios-bugfix",
      displayName: "ios-bugfix",
      kind: .session,
      isMissing: false,
      badges: []
    )

    #expect(StudioLibraryUsageState.rowSubtitle(for: named, kindTitle: "Kit") == "Kit · cli-guardrails")
    #expect(StudioLibraryUsageState.rowSubtitle(for: bare, kindTitle: "Session") == "Session")
    #expect(
      StudioLibraryUsageState.rowAccessibilityLabel(for: named, kindTitle: "Kit")
        == "Open Kit CLI Guardrails, cli-guardrails"
    )
    #expect(
      StudioLibraryUsageState.rowAccessibilityLabel(for: bare, kindTitle: "Session") == "Open Session ios-bugfix"
    )
  }

}
