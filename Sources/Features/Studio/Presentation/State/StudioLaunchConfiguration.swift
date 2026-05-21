import Foundation

/// Launch-time configuration shared by Studio app entry points and tests.
public enum StudioLaunchConfiguration {
  public static let disableAutoActivateEnvironmentKey =
    "PERSONAKIT_STUDIO_DISABLE_AUTO_ACTIVATE"
  public static let initialSectionEnvironmentKey =
    "PERSONAKIT_STUDIO_INITIAL_SECTION"
  public static let launchWorkspacePathEnvironmentKey =
    "PERSONAKIT_STUDIO_INITIAL_WORKSPACE_PATH"
  public static let globalScopePathEnvironmentKey =
    "PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH"
  public static let relationshipMapGeometryFileEnvironmentKey =
    "PERSONAKIT_STUDIO_REVIEW_GEOMETRY_FILE"
  public static let userDefaultsSuiteNameEnvironmentKey =
    "PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME"

  public static func shouldAutoActivate(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> Bool {
    if arguments.contains("--no-auto-activate") {
      return false
    }

    guard
      let rawValue = environment[disableAutoActivateEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      return true
    }

    switch rawValue.lowercased() {
    case "1", "true", "yes":
      return false
    default:
      return true
    }
  }

  public static func launchWorkspaceURL(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> URL? {
    let rawPath =
      launchWorkspacePath(from: arguments)
      ?? environment[launchWorkspacePathEnvironmentKey]

    guard
      let trimmedPath = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmedPath.isEmpty
    else {
      return nil
    }

    return URL(
      fileURLWithPath: (trimmedPath as NSString).expandingTildeInPath,
      isDirectory: true
    )
    .standardizedFileURL
  }

  public static func globalScopeURL(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL? {
    guard
      let trimmedPath = environment[globalScopePathEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmedPath.isEmpty
    else {
      return nil
    }

    return URL(
      fileURLWithPath: (trimmedPath as NSString).expandingTildeInPath,
      isDirectory: true
    )
    .standardizedFileURL
  }

  public static func relationshipMapGeometryFileURL(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL? {
    guard
      let trimmedPath = environment[relationshipMapGeometryFileEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmedPath.isEmpty
    else {
      return nil
    }

    return URL(
      fileURLWithPath: (trimmedPath as NSString).expandingTildeInPath
    )
    .standardizedFileURL
  }

  public static func initialSection(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> StudioLaunchSection {
    let rawSection =
      argumentValue(for: "--section", in: arguments)
      ?? environment[initialSectionEnvironmentKey]

    guard
      let trimmedSection = rawSection?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmedSection.isEmpty
    else {
      return .sessions
    }

    return StudioLaunchSection(rawValue: trimmedSection) ?? .sessions
  }

  public static func userDefaults(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> UserDefaults {
    guard
      let suiteName = userDefaultsSuiteName(environment: environment),
      let defaults = UserDefaults(suiteName: suiteName)
    else {
      return .standard
    }

    return defaults
  }

  private static func launchWorkspacePath(from arguments: [String]) -> String? {
    argumentValue(for: "--workspace", in: arguments)
  }

  private static func userDefaultsSuiteName(
    environment: [String: String]
  ) -> String? {
    guard
      let trimmedSuiteName = environment[userDefaultsSuiteNameEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmedSuiteName.isEmpty
    else {
      return nil
    }

    return trimmedSuiteName
  }

  private static func argumentValue(
    for flag: String,
    in arguments: [String]
  ) -> String? {
    guard let flagIndex = arguments.firstIndex(of: flag) else {
      return nil
    }

    let valueIndex = arguments.index(after: flagIndex)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }

    return arguments[valueIndex]
  }
}

public enum StudioLaunchSection: String, Sendable {
  case directives
  case essentials
  case intents
  case kits
  case personas
  case references
  case relationshipMap = "relationship-map"
  case sessions
  case skills
  case validationResults = "validation-results"
}
