import Foundation

public enum StudioInstallOutcome: String, Equatable, Sendable {
  case installed
  case updated
  case failed
}

public struct StudioInstallResult: Equatable, Sendable {
  public let outcome: StudioInstallOutcome
  public let title: String
  public let message: String

  public init(
    outcome: StudioInstallOutcome,
    title: String,
    message: String
  ) {
    self.outcome = outcome
    self.title = title
    self.message = message
  }
}

public struct WorkspaceInstallStatus: Equatable, Sendable {
  public let bundledCLIURL: URL?
  public let installedCLIURL: URL?
  public let openCodeConfigURL: URL
  public let openCodeMCPCommandPath: String?

  public init(
    bundledCLIURL: URL?,
    installedCLIURL: URL?,
    openCodeConfigURL: URL,
    openCodeMCPCommandPath: String?
  ) {
    self.bundledCLIURL = bundledCLIURL
    self.installedCLIURL = installedCLIURL
    self.openCodeConfigURL = openCodeConfigURL
    self.openCodeMCPCommandPath = openCodeMCPCommandPath
  }
}

public protocol WorkspaceInstallEnvironmentProviding {
  @MainActor
  func homeDirectoryURL() -> URL

  @MainActor
  func bundledCLIURL() -> URL?

  @MainActor
  func bundledCLISupportBundleURL() -> URL?
}

public struct WorkspaceInstallEnvironmentClient: WorkspaceInstallEnvironmentProviding {
  private let bundleProvider: @MainActor () -> Bundle
  private let homeDirectoryProvider: @MainActor () -> URL

  public init(
    bundleProvider: @escaping @MainActor () -> Bundle = { .main },
    homeDirectoryProvider: @escaping @MainActor () -> URL = {
      FileManager.default.homeDirectoryForCurrentUser
    }
  ) {
    self.bundleProvider = bundleProvider
    self.homeDirectoryProvider = homeDirectoryProvider
  }

  @MainActor
  public func homeDirectoryURL() -> URL {
    homeDirectoryProvider().standardizedFileURL
  }

  @MainActor
  public func bundledCLIURL() -> URL? {
    executableCandidateURLs().first(where: {
      FileManager.default.isExecutableFile(atPath: $0.path())
    })
  }

  @MainActor
  public func bundledCLISupportBundleURL() -> URL? {
    bundleCandidateURLs(named: "PersonaKit_ContextCore.bundle").first(where: { url in
      FileManager.default.fileExists(atPath: url.path())
    })
  }

  @MainActor
  private func executableCandidateURLs() -> [URL] {
    bundleCandidateURLs(named: "PersonaKitCLI")
  }

  @MainActor
  private func bundleCandidateURLs(named name: String) -> [URL] {
    let bundle = bundleProvider()
    return [
      bundle.resourceURL?.appendingPathComponent(name),
      bundle.resourceURL?.appendingPathComponent("InstallSupport/\(name)"),
      bundle.bundleURL.appendingPathComponent("Contents/Resources/\(name)"),
      bundle.bundleURL.appendingPathComponent("Contents/Resources/InstallSupport/\(name)"),
      bundle.bundleURL.appendingPathComponent("Contents/MacOS/\(name)"),
    ]
    .compactMap { $0?.standardizedFileURL }
  }
}
