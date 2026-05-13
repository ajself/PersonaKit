import Testing

@testable import StudioFeatures

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

  @Test
  func launchWorkspaceURLUsesWorkspaceArgument() {
    let url = StudioLaunchConfiguration.launchWorkspaceURL(
      environment: [
        StudioLaunchConfiguration.launchWorkspacePathEnvironmentKey:
          "/tmp/personakit-env-workspace"
      ],
      arguments: ["PersonaKitStudio", "--workspace", "/tmp/personakit-arg-workspace"]
    )

    #expect(url?.path == "/tmp/personakit-arg-workspace")
  }

  @Test
  func launchWorkspaceURLFallsBackToEnvironment() {
    let url = StudioLaunchConfiguration.launchWorkspaceURL(
      environment: [
        StudioLaunchConfiguration.launchWorkspacePathEnvironmentKey:
          "/tmp/personakit-env-workspace"
      ],
      arguments: ["PersonaKitStudio"]
    )

    #expect(url?.path == "/tmp/personakit-env-workspace")
  }

  @Test
  func launchWorkspaceURLIgnoresMissingArgumentValue() {
    let url = StudioLaunchConfiguration.launchWorkspaceURL(
      environment: [:],
      arguments: ["PersonaKitStudio", "--workspace"]
    )

    #expect(url == nil)
  }

  @Test
  func globalScopeURLUsesEnvironmentOverride() {
    let url = StudioLaunchConfiguration.globalScopeURL(
      environment: [
        StudioLaunchConfiguration.globalScopePathEnvironmentKey:
          "/tmp/personakit-review-global/.personakit"
      ]
    )

    #expect(url?.path == "/tmp/personakit-review-global/.personakit")
  }

  @Test
  func initialSectionDefaultsToSessions() {
    #expect(
      StudioLaunchConfiguration.initialSection(
        environment: [:],
        arguments: ["PersonaKitStudio"]
      ) == .sessions
    )
  }

  @Test
  func initialSectionUsesSectionArgument() {
    #expect(
      StudioLaunchConfiguration.initialSection(
        environment: [
          StudioLaunchConfiguration.initialSectionEnvironmentKey: "personas"
        ],
        arguments: ["PersonaKitStudio", "--section", "relationship-map"]
      ) == .relationshipMap
    )
  }

  @Test
  func initialSectionFallsBackToEnvironment() {
    #expect(
      StudioLaunchConfiguration.initialSection(
        environment: [
          StudioLaunchConfiguration.initialSectionEnvironmentKey:
            "validation-results"
        ],
        arguments: ["PersonaKitStudio"]
      ) == .validationResults
    )
  }

  @Test
  func initialSectionIgnoresUnknownValues() {
    #expect(
      StudioLaunchConfiguration.initialSection(
        environment: [
          StudioLaunchConfiguration.initialSectionEnvironmentKey: "unknown"
        ],
        arguments: ["PersonaKitStudio"]
      ) == .sessions
    )
  }
}
