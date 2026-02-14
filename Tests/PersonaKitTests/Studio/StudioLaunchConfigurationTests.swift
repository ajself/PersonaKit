import Testing

@testable import PersonaKitStudio

struct StudioLaunchConfigurationTests {
  @Test
  func shouldAutoActivateDefaultsToTrue() {
    #expect(StudioLaunchConfiguration.shouldAutoActivate(environment: [:], arguments: []))
  }

  @Test
  func shouldAutoActivateReturnsFalseForArgumentOverride() {
    #expect(
      !StudioLaunchConfiguration.shouldAutoActivate(
        environment: [:],
        arguments: ["PersonaKitStudio", "--no-auto-activate"]
      )
    )
  }

  @Test
  func shouldAutoActivateReturnsFalseForDisableEnvironmentValues() {
    let key = StudioLaunchConfiguration.disableAutoActivateEnvironmentKey

    #expect(
      !StudioLaunchConfiguration.shouldAutoActivate(
        environment: [key: "1"],
        arguments: ["PersonaKitStudio"]
      )
    )
    #expect(
      !StudioLaunchConfiguration.shouldAutoActivate(
        environment: [key: "true"],
        arguments: ["PersonaKitStudio"]
      )
    )
    #expect(
      !StudioLaunchConfiguration.shouldAutoActivate(
        environment: [key: "YES"],
        arguments: ["PersonaKitStudio"]
      )
    )
  }

  @Test
  func shouldAutoActivateIgnoresUnknownEnvironmentValues() {
    let key = StudioLaunchConfiguration.disableAutoActivateEnvironmentKey

    #expect(
      StudioLaunchConfiguration.shouldAutoActivate(
        environment: [key: "0"],
        arguments: ["PersonaKitStudio"]
      )
    )
  }
}
