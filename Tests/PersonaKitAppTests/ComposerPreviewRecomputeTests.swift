import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("Composer Preview Recompute")
struct ComposerPreviewRecomputeTests {
  @Test("Composer edits recompute the prompt preview")
  @MainActor
  func composerEditsRecomputePreview() {
    let store = AppStore()
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
    store.state.personaIndex = resolution.personasByID
    store.state.composer.selectedPersonaID = "test-persona"

    store.send(.composer(.setComposerValue(key: "context", value: "Hello")))

    #expect(store.state.preview.promptPreview == "System\n\nCONTEXT\nHello\n")
  }
}
