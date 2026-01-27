import Clocks
import Dependencies
import PersonaKitCore
import Testing

@testable import PersonaKitApp

@Suite("App Preview Parity")
struct AppPreviewParityTests {
  @Test("App prompt preview matches core renderer")
  @MainActor
  func appPromptPreviewMatchesCoreRenderer() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let persona = Persona(
      id: "parity-persona",
      name: "Parity Persona",
      system: "System",
      template: PromptTemplate(
        sections: [
          TemplateSection(key: "context", label: "Context", required: true),
          TemplateSection(key: "task", label: "Task", required: true)
        ]
      )
    )
    let resolution = PersonaResolver.resolveAll(from: ["parity-persona": persona])
    model.personaIndex = resolution.personasByID

    model.selectPersona(id: "parity-persona")
    model.updateComposerValue(key: "context", value: "Repo: PersonaKit")
    model.updateComposerValue(key: "task", value: "Verify parity")

    let expected = PersonaOutputRenderer.prompt(
      persona: persona,
      sections: [
        "context": "Repo: PersonaKit",
        "task": "Verify parity"
      ]
    )

    #expect(model.preview.promptPreview == expected)

    await clock.advance(by: .milliseconds(400))
    await clock.run()
  }

  @Test("App JSON preview matches core renderer")
  @MainActor
  func appJSONPreviewMatchesCoreRenderer() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let persona = Persona(
      id: "json-parity-persona",
      name: "JSON Parity Persona",
      system: "System",
      template: PromptTemplate(
        sections: [
          TemplateSection(key: "context", label: "Context", required: true)
        ]
      )
    )
    let resolution = PersonaResolver.resolveAll(from: ["json-parity-persona": persona])
    model.personaIndex = resolution.personasByID

    model.selectPersona(id: "json-parity-persona")

    let expected =
      PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true) ?? ""
    #expect(model.preview.jsonPreview == expected)

    await clock.advance(by: .milliseconds(400))
    await clock.run()
    #expect(model.preview.jsonPreview == expected)
  }
}
