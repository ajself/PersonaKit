import Foundation

public protocol StudioLaunchEnvironmentReading {
  var arguments: [String] { get }
  var environment: [String: String] { get }
}

public protocol StudioUserDefaultsResolving {
  func userDefaults(suiteName: String?) -> UserDefaults?
}

public struct StudioLaunchEnvironmentClient: StudioLaunchEnvironmentReading {
  public let arguments: [String]
  public let environment: [String: String]

  public init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) {
    self.arguments = arguments
    self.environment = environment
  }
}

public struct StudioUserDefaultsClient: StudioUserDefaultsResolving {
  public init() {}

  public func userDefaults(suiteName: String?) -> UserDefaults? {
    guard let suiteName else {
      return .standard
    }

    return UserDefaults(suiteName: suiteName)
  }
}

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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient()
  ) -> Bool {
    shouldAutoActivate(
      environment: launchEnvironment.environment,
      arguments: launchEnvironment.arguments
    )
  }

  public static func shouldAutoActivate(
    environment: [String: String],
    arguments: [String]
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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient()
  ) -> URL? {
    launchWorkspaceURL(
      environment: launchEnvironment.environment,
      arguments: launchEnvironment.arguments
    )
  }

  public static func launchWorkspaceURL(
    environment: [String: String],
    arguments: [String]
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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient()
  ) -> URL? {
    globalScopeURL(environment: launchEnvironment.environment)
  }

  public static func globalScopeURL(
    environment: [String: String]
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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient()
  ) -> URL? {
    relationshipMapGeometryFileURL(environment: launchEnvironment.environment)
  }

  public static func relationshipMapGeometryFileURL(
    environment: [String: String]
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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient()
  ) -> StudioLaunchSection {
    initialSection(
      environment: launchEnvironment.environment,
      arguments: launchEnvironment.arguments
    )
  }

  public static func initialSection(
    environment: [String: String],
    arguments: [String]
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
    launchEnvironment: any StudioLaunchEnvironmentReading = StudioLaunchEnvironmentClient(),
    userDefaultsResolver: any StudioUserDefaultsResolving = StudioUserDefaultsClient()
  ) -> UserDefaults {
    userDefaults(
      environment: launchEnvironment.environment,
      userDefaultsResolver: userDefaultsResolver
    )
  }

  public static func userDefaults(
    environment: [String: String],
    userDefaultsResolver: any StudioUserDefaultsResolving = StudioUserDefaultsClient()
  ) -> UserDefaults {
    userDefaultsResolver.userDefaults(
      suiteName: userDefaultsSuiteName(environment: environment)
    )
      ?? .standard
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
  case kits
  case personas
  case relationshipMap = "relationship-map"
  case sessions
  case skills
  case validationResults = "validation-results"
}
