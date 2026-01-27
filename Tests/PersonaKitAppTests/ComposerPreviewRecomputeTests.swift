import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("Composer Preview Recompute")
struct ComposerPreviewRecomputeTests {
  @Test("Composer edits recompute the prompt preview")
  @MainActor
  func composerEditsRecomputePreview() {
    let model = AppModel()
    let persona = Persona(
      id: "test-persona",
      name: "Test Persona",
      system: "System",
      template: PromptTemplate(
        sections: [
          TemplateSection(key: "context", label: "Context", required: true)
        ]
      )
    )
    let resolution = PersonaResolver.resolveAll(from: ["test-persona": persona])
    model.personaIndex = resolution.personasByID
    model.composer.selectedPersonaID = "test-persona"

    model.updateComposerValue(key: "context", value: "Hello")

    #expect(model.preview.promptPreview == "System\n\nCONTEXT\nHello\n")
  }
}
