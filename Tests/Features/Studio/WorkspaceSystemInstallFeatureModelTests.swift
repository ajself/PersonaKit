import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceSystemInstallFeatureModelTests {
  @Test
  func installCLIInstallsBundledExecutableIntoUserBinDirectory() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateCLI()
    let installedCLIURL = homeDirectoryURL.appendingPathComponent(".local/bin/personakit")
    let installedSupportBundleURL = homeDirectoryURL.appendingPathComponent(
      ".local/bin/PersonaKit_ContextCore.bundle/Contents/Resources/marker.txt"
    )

    #expect(result.outcome == .installed)
    #expect(FileManager.default.isExecutableFile(atPath: installedCLIURL.path()))
    let installedContents = try String(contentsOf: installedCLIURL, encoding: .utf8)
    #expect(installedContents == "bundled-cli")
    let installedBundleContents = try String(contentsOf: installedSupportBundleURL, encoding: .utf8)
    #expect(installedBundleContents == "bundled-support")
  }

  @Test
  func installCLIUpdatesExistingExecutableInPlace() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let installedCLIURL = homeDirectoryURL.appendingPathComponent(".local/bin/personakit")
    try makeExecutableFile(
      at: installedCLIURL,
      contents: "old-cli"
    )
    try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/PersonaKit_ContextCore.bundle"),
      marker: "old-support"
    )

    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "new-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "new-support"
    )
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateCLI()

    #expect(result.outcome == .updated)
    let installedContents = try String(contentsOf: installedCLIURL, encoding: .utf8)
    #expect(installedContents == "new-cli")
    let installedBundleContents = try String(
      contentsOf: homeDirectoryURL.appendingPathComponent(
        ".local/bin/PersonaKit_ContextCore.bundle/Contents/Resources/marker.txt"
      ),
      encoding: .utf8
    )
    #expect(installedBundleContents == "new-support")
  }

  @Test
  func installCLIRepairsExistingExecutableMissingSupportBundle() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let installedCLIURL = homeDirectoryURL.appendingPathComponent(".local/bin/personakit")
    try makeExecutableFile(
      at: installedCLIURL,
      contents: "old-cli"
    )

    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "new-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "new-support"
    )
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateCLI()

    #expect(result.outcome == .updated)
    let installedContents = try String(contentsOf: installedCLIURL, encoding: .utf8)
    #expect(installedContents == "new-cli")
    let installedBundleContents = try String(
      contentsOf: homeDirectoryURL.appendingPathComponent(
        ".local/bin/PersonaKit_ContextCore.bundle/Contents/Resources/marker.txt"
      ),
      encoding: .utf8
    )
    #expect(installedBundleContents == "new-support")
  }

  @Test
  func installCLIFailsWhenBundledExecutableIsMissing() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: nil,
      bundledCLISupportBundleURL: nil
    )

    let result = model.installOrUpdateCLI()

    #expect(result.outcome == .failed)
    #expect(result.title == "CLI Install Failed")
  }

  @Test
  func installCLIUsesInjectedInstallFileSystem() throws {
    let homeDirectoryURL = URL(fileURLWithPath: "/StudioHome")
    let bundledCLIURL = URL(fileURLWithPath: "/Bundle/PersonaKitCLI")
    let bundledSupportBundleURL = URL(fileURLWithPath: "/Bundle/PersonaKit_ContextCore.bundle")
    let fileSystem = WorkspaceSystemInstallRecordingFileSystem()
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL,
      installFileSystem: fileSystem
    )

    let result = model.installOrUpdateCLI()

    #expect(result.outcome == .installed)
    #expect(
      fileSystem.operations == [
        "exists:/StudioHome/.local/bin/personakit",
        "exists:/StudioHome/.local/bin/PersonaKit_ContextCore.bundle",
        "createDirectory:/StudioHome/.local/bin/",
        "exists:/StudioHome/.local/bin/.personakit-install.tmp",
        "exists:/StudioHome/.local/bin/.personakit-install.bundle.tmp",
        "copy:/Bundle/PersonaKitCLI->/StudioHome/.local/bin/.personakit-install.tmp",
        "copy:/Bundle/PersonaKit_ContextCore.bundle->/StudioHome/.local/bin/.personakit-install.bundle.tmp",
        "setExecutable:/StudioHome/.local/bin/.personakit-install.tmp",
        "move:/StudioHome/.local/bin/.personakit-install.tmp->/StudioHome/.local/bin/personakit",
        "move:/StudioHome/.local/bin/.personakit-install.bundle.tmp->/StudioHome/.local/bin/PersonaKit_ContextCore.bundle",
      ]
    )
  }

  @Test
  func installOpenCodeMCPCreatesNewGlobalConfig() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateOpenCodeMCP()
    let configURL = homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.json")
    let configObject = try loadJSONObject(at: configURL)
    let mcp = try #require(configObject["mcp"] as? [String: Any])
    let personakit = try #require(mcp["personakit"] as? [String: Any])
    let command = try #require(personakit["command"] as? [String])

    #expect(result.outcome == .installed)
    #expect(command == [bundledCLIURL.path(), "mcp"])
  }

  @Test
  func installOpenCodeMCPMergesIntoExistingJSONConfig() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let configURL = homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.json")

    try writeText(
      """
      {
        "model" : "anthropic/claude-sonnet-4-5",
        "mcp" : {
          "other" : {
            "type" : "remote",
            "url" : "https://example.com/mcp"
          }
        }
      }
      """,
      to: configURL
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateOpenCodeMCP()
    let configObject = try loadJSONObject(at: configURL)
    let mcp = try #require(configObject["mcp"] as? [String: Any])

    #expect(result.outcome == .installed)
    #expect(configObject["model"] as? String == "anthropic/claude-sonnet-4-5")
    #expect(mcp["other"] != nil)
    #expect(mcp["personakit"] != nil)
  }

  @Test
  func installOpenCodeMCPFailsSafelyForExistingJSONCConfig() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let configURL = homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.jsonc")

    try writeText(
      """
      {
        // Keep this existing setting.
        "model" : "anthropic/claude-sonnet-4-5",
        "mcp" : {
          "other" : {
            "type" : "remote",
            "url" : "https://example.com/mcp",
          },
        },
      }
      """,
      to: configURL
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateOpenCodeMCP()

    #expect(result.outcome == .failed)
    #expect(result.message.contains(configURL.path()))
    #expect(result.message.contains("\"personakit\""))
    let preservedContents = try String(contentsOf: configURL, encoding: .utf8)
    #expect(preservedContents.contains("// Keep this existing setting."))
  }

  @Test
  func installOpenCodeMCPPrefersInstalledCLIWhenAvailable() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let installedCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/personakit"),
      contents: "installed-cli"
    )
    try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/PersonaKit_ContextCore.bundle"),
      marker: "installed-support"
    )
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateOpenCodeMCP()
    let configObject = try loadJSONObject(
      at: homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.json")
    )
    let mcp = try #require(configObject["mcp"] as? [String: Any])
    let personakit = try #require(mcp["personakit"] as? [String: Any])
    let command = try #require(personakit["command"] as? [String])

    #expect(result.outcome == .installed)
    #expect(command == [installedCLIURL.path(), "mcp"])
  }

  @Test
  func installOpenCodeMCPFailsSafelyForInvalidConfig() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let configURL = homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.json")

    try writeText(
      """
      {
        "mcp":
      """,
      to: configURL
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )

    let result = model.installOrUpdateOpenCodeMCP()

    #expect(result.outcome == .failed)
    #expect(result.message.contains(configURL.path()))
    #expect(result.message.contains("\"personakit\""))
  }

  @Test
  func installOpenCodeMCPUsesInjectedConfigFileAccess() throws {
    let homeDirectoryURL = URL(fileURLWithPath: "/StudioHome")
    let bundledCLIURL = URL(fileURLWithPath: "/Bundle/PersonaKitCLI")
    let bundledSupportBundleURL = URL(fileURLWithPath: "/Bundle/PersonaKit_ContextCore.bundle")
    let fileSystem = WorkspaceSystemInstallRecordingFileSystem()
    let configFile = WorkspaceSystemInstallRecordingOpenCodeConfigFile()
    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL,
      installFileSystem: fileSystem,
      openCodeConfigFile: configFile
    )

    let result = model.installOrUpdateOpenCodeMCP()

    let writtenConfig = try #require(configFile.writtenConfig)
    let configObject = try #require(
      JSONSerialization.jsonObject(with: writtenConfig.data) as? [String: Any]
    )
    let mcp = try #require(configObject["mcp"] as? [String: Any])
    let personakit = try #require(mcp["personakit"] as? [String: Any])
    let command = try #require(personakit["command"] as? [String])

    #expect(result.outcome == .installed)
    #expect(writtenConfig.url.path() == "/StudioHome/.config/opencode/opencode.json")
    #expect(command == ["/Bundle/PersonaKitCLI", "mcp"])
    #expect(fileSystem.operations.contains("createDirectory:/StudioHome/.config/opencode/"))
  }

  @Test
  func refreshInstallStatusReportsCurrentCLIAndMCPState() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let installedCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/personakit"),
      contents: "installed-cli"
    )
    try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/PersonaKit_ContextCore.bundle"),
      marker: "installed-support"
    )

    try writeText(
      """
      {
        "$schema" : "https://opencode.ai/config.json",
        "mcp" : {
          "personakit" : {
            "command" : [
              "\(installedCLIURL.path())",
              "mcp"
            ],
            "enabled" : true,
            "type" : "local"
          }
        }
      }
      """,
      to: homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.json")
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )
    let status = model.refreshInstallStatus()

    #expect(status.bundledCLIURL == bundledCLIURL.standardizedFileURL)
    #expect(status.installedCLIURL == installedCLIURL.standardizedFileURL)
    #expect(status.openCodeMCPCommandPath == installedCLIURL.path())
  }

  @Test
  func refreshInstallStatusReadsExistingJSONCConfig() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    let installedCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/personakit"),
      contents: "installed-cli"
    )
    try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/PersonaKit_ContextCore.bundle"),
      marker: "installed-support"
    )
    let configURL = homeDirectoryURL.appendingPathComponent(".config/opencode/opencode.jsonc")

    try writeText(
      """
      {
        // Keep this comment intact.
        "mcp" : {
          "personakit" : {
            "command" : [
              "\(installedCLIURL.path())",
              "mcp"
            ],
            "enabled" : true,
            "type" : "local",
          },
        },
      }
      """,
      to: configURL
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )
    let status = model.refreshInstallStatus()

    #expect(status.bundledCLIURL == bundledCLIURL.standardizedFileURL)
    #expect(status.installedCLIURL == installedCLIURL.standardizedFileURL)
    #expect(status.openCodeConfigURL == configURL.standardizedFileURL)
    #expect(status.openCodeMCPCommandPath == installedCLIURL.path())
  }

  @Test
  func refreshInstallStatusIgnoresInstalledCLIWithoutSupportBundle() throws {
    let homeDirectoryURL = try makeInstallTempDirectory()
    let bundledCLIURL = try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI"),
      contents: "bundled-cli"
    )
    let bundledSupportBundleURL = try makeSupportBundle(
      at: homeDirectoryURL.appendingPathComponent("Bundle/PersonaKit_ContextCore.bundle"),
      marker: "bundled-support"
    )
    try makeExecutableFile(
      at: homeDirectoryURL.appendingPathComponent(".local/bin/personakit"),
      contents: "installed-cli"
    )

    let model = makeModel(
      homeDirectoryURL: homeDirectoryURL,
      bundledCLIURL: bundledCLIURL,
      bundledCLISupportBundleURL: bundledSupportBundleURL
    )
    let status = model.refreshInstallStatus()

    #expect(status.bundledCLIURL == bundledCLIURL.standardizedFileURL)
    #expect(status.installedCLIURL == nil)
  }

  private func makeModel(
    homeDirectoryURL: URL,
    bundledCLIURL: URL?,
    bundledCLISupportBundleURL: URL?,
    installFileSystem: any WorkspaceInstallFileOperating =
      WorkspaceInstallFileSystemClient(),
    openCodeConfigFile: any OpenCodeConfigurationFileAccessing =
      OpenCodeConfigurationFileClient()
  ) -> WorkspaceSystemFeatureModel {
    WorkspaceSystemFeatureModel(
      workspacePicker: WorkspaceSystemInstallStubWorkspacePicker(),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: WorkspaceSystemInstallSpyFileRevealer(),
      installEnvironment: WorkspaceSystemInstallStubEnvironment(
        rootHomeDirectoryURL: homeDirectoryURL,
        resolvedBundledCLIURL: bundledCLIURL,
        resolvedBundledCLISupportBundleURL: bundledCLISupportBundleURL
      ),
      installFileSystem: installFileSystem,
      openCodeConfigFile: openCodeConfigFile
    )
  }
}

private final class WorkspaceSystemInstallRecordingFileSystem: WorkspaceInstallFileOperating {
  private(set) var operations: [String] = []
  var existingPaths: Set<String> = []
  var executablePaths: Set<String> = []

  @MainActor
  func copyItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws {
    operations.append("copy:\(sourceURL.path())->\(destinationURL.path())")
    existingPaths.insert(destinationURL.path())
  }

  @MainActor
  func createDirectory(at url: URL) throws {
    operations.append("createDirectory:\(url.path())")
    existingPaths.insert(url.path())
  }

  @MainActor
  func fileExists(at url: URL) -> Bool {
    operations.append("exists:\(url.path())")
    return existingPaths.contains(url.path())
  }

  @MainActor
  func isExecutableFile(at url: URL) -> Bool {
    operations.append("executable:\(url.path())")
    return executablePaths.contains(url.path())
  }

  @MainActor
  func moveItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws {
    operations.append("move:\(sourceURL.path())->\(destinationURL.path())")
    existingPaths.remove(sourceURL.path())
    existingPaths.insert(destinationURL.path())

    if executablePaths.remove(sourceURL.path()) != nil {
      executablePaths.insert(destinationURL.path())
    }
  }

  @MainActor
  func removeItem(at url: URL) throws {
    operations.append("remove:\(url.path())")
    existingPaths.remove(url.path())
    executablePaths.remove(url.path())
  }

  @MainActor
  func replaceItem(
    at targetURL: URL,
    with sourceURL: URL
  ) throws {
    operations.append("replace:\(sourceURL.path())->\(targetURL.path())")
    existingPaths.remove(sourceURL.path())
    existingPaths.insert(targetURL.path())

    if executablePaths.remove(sourceURL.path()) != nil {
      executablePaths.insert(targetURL.path())
    }
  }

  @MainActor
  func setExecutableFile(at url: URL) throws {
    operations.append("setExecutable:\(url.path())")
    executablePaths.insert(url.path())
  }
}

private final class WorkspaceSystemInstallRecordingOpenCodeConfigFile:
  OpenCodeConfigurationFileAccessing
{
  private(set) var writtenConfig: (data: Data, url: URL)?
  var existingConfigData: [String: Data] = [:]

  @MainActor
  func configExists(at url: URL) -> Bool {
    existingConfigData[url.path()] != nil
  }

  @MainActor
  func readConfigData(at url: URL) throws -> Data {
    existingConfigData[url.path()] ?? Data()
  }

  @MainActor
  func writeConfigData(
    _ data: Data,
    to url: URL
  ) throws {
    writtenConfig = (data, url.standardizedFileURL)
    existingConfigData[url.path()] = data
  }
}

private struct WorkspaceSystemInstallStubWorkspacePicker: WorkspacePicking {
  @MainActor
  func pickWorkspaceURL() -> URL? {
    nil
  }
}

private final class WorkspaceSystemInstallSpyFileRevealer: FileRevealing {
  @MainActor
  func reveal(_ url: URL) {}
}

private struct WorkspaceSystemInstallStubEnvironment: WorkspaceInstallEnvironmentProviding {
  let rootHomeDirectoryURL: URL
  let resolvedBundledCLIURL: URL?
  let resolvedBundledCLISupportBundleURL: URL?

  @MainActor
  func homeDirectoryURL() -> URL {
    rootHomeDirectoryURL.standardizedFileURL
  }

  @MainActor
  func bundledCLIURL() -> URL? {
    resolvedBundledCLIURL?.standardizedFileURL
  }

  @MainActor
  func bundledCLISupportBundleURL() -> URL? {
    resolvedBundledCLISupportBundleURL?.standardizedFileURL
  }
}

private func makeInstallTempDirectory() throws -> URL {
  let directoryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
  )
  return directoryURL.standardizedFileURL
}

@discardableResult
private func makeExecutableFile(
  at url: URL,
  contents: String
) throws -> URL {
  guard let data = contents.data(using: .utf8) else {
    throw CocoaError(.fileWriteUnknown)
  }

  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try data.write(to: url, options: [.atomic])
  try FileManager.default.setAttributes(
    [.posixPermissions: 0o755],
    ofItemAtPath: url.path()
  )
  return url.standardizedFileURL
}

private func writeText(
  _ value: String,
  to url: URL
) throws {
  guard let data = value.data(using: .utf8) else {
    throw CocoaError(.fileWriteUnknown)
  }

  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try data.write(to: url, options: [.atomic])
}

@discardableResult
private func makeSupportBundle(
  at url: URL,
  marker: String
) throws -> URL {
  let markerURL =
    url
    .appendingPathComponent("Contents/Resources/marker.txt")
    .standardizedFileURL
  try writeText(marker, to: markerURL)
  return url.standardizedFileURL
}

private func loadJSONObject(at url: URL) throws -> [String: Any] {
  let data = try Data(contentsOf: url)
  return try #require(
    JSONSerialization.jsonObject(with: data) as? [String: Any]
  )
}
