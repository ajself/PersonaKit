import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryPreviewStateTests {
  @Test
  func previewUsesMetadataAndWorkspaceRelativePath() {
    let state = StudioLibraryPreviewState(
      selection: .personas,
      item: WorkspaceListItem(
        id: "solo-developer",
        displayName: "Solo Developer",
        fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo-developer.persona.json"),
        sourceScope: .project
      ),
      workspaceURL: URL(fileURLWithPath: "/Workspace/")
    )

    #expect(state.sectionTitle == "Persona")
    #expect(state.id == "solo-developer")
    #expect(state.displayName == "Solo Developer")
    #expect(state.scope == "Project")
    #expect(state.relativePath == ".personakit/Packs/personas/solo-developer.persona.json")
    #expect(state.accessibilitySummary.contains("Persona Preview"))
  }

  @Test
  func previewIncludesWorkstreamRoutingMetadataWhenPresent() {
    let state = StudioLibraryPreviewState(
      selection: .directives,
      item: WorkspaceListItem(
        id: "small-cli-change",
        displayName: "Make a small CLI change",
        fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/directives/small-cli-change.directive.json"),
        sourceScope: .project,
        workstreamId: "v1",
        workstreamPhase: "review"
      ),
      workspaceURL: URL(fileURLWithPath: "/Workspace")
    )

    #expect(state.workstreamLine == "workstream: v1 · phase: review")
  }

  @Test
  func skillPreviewExplainsCapabilityBoundaryMetadata() {
    let state = StudioLibraryPreviewState(
      selection: .skills,
      item: WorkspaceListItem(
        id: "opencode-cli",
        displayName: "OpenCode CLI",
        fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/skills/opencode-cli.skill.json"),
        sourceScope: .project,
        skillMetadata: WorkspaceSkillMetadata(
          description: "Allows OpenCode to perform bounded code edits from resolved PersonaKit context.",
          providedBy: ["opencode"],
          riskLevel: "medium",
          requiresHumanReview: true,
          notes: ["PersonaKit resolves context; OpenCode performs work."]
        )
      ),
      workspaceURL: URL(fileURLWithPath: "/Workspace")
    )

    #expect(
      state.skillCapabilityLine
        == "Allows OpenCode to perform bounded code edits from resolved PersonaKit context."
    )
    #expect(state.skillBoundaryLine == "Capability boundary, not a runnable command.")
    #expect(state.skillProviderLine == "opencode")
    #expect(state.skillRiskLine == "medium")
    #expect(state.skillReviewLine == "Required")
    #expect(state.skillNotesLine == "PersonaKit resolves context; OpenCode performs work.")
    #expect(state.accessibilitySummary.contains("provided by opencode"))
  }
}
