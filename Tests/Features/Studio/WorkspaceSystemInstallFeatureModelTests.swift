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
    bundledCLISupportBundleURL: URL?
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
      )
    )
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
  let markerURL = url
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
