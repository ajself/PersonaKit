import Testing
@testable import PersonaKit

struct PersonaKitHostTests {
  @Test
  func autoActivateDefaultsToTrue() {
    #expect(PersonaKitLaunchConfiguration.shouldAutoActivate(environment: [:], arguments: []) == true)
  }

  @Test
  func autoActivateCanBeDisabledViaArgument() {
    #expect(
      PersonaKitLaunchConfiguration.shouldAutoActivate(
        environment: [:],
        arguments: ["PersonaKit", "--no-auto-activate"]
      ) == false
    )
  }

  @Test
  func autoActivateCanBeDisabledViaEnvironmentVariable() {
    #expect(
      PersonaKitLaunchConfiguration.shouldAutoActivate(
        environment: ["PERSONAKIT_STUDIO_DISABLE_AUTO_ACTIVATE": "true"],
        arguments: []
      ) == false
    )
  }
}
