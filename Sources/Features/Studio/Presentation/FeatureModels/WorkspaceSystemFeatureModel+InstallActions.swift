import Foundation
import StudioFoundation

extension WorkspaceSystemFeatureModel {
  private static let cliInstallSubpath = ".local/bin/personakit"
  private static let cliSupportBundleName = "PersonaKit_ContextCore.bundle"
  private static let openCodeDirectorySubpath = ".config/opencode"
  private static let openCodeJSONFilename = "opencode.json"
  private static let openCodeJSONCFilename = "opencode.jsonc"
  private static let openCodeSchemaURL = "https://opencode.ai/config.json"
  private static let personakitMCPName = "personakit"

  func refreshInstallStatus() -> WorkspaceInstallStatus {
    let installEnvironment = installEnvironmentStatus()
    let installFileSystem = installFileSystemClient()
    let openCodeConfigFile = openCodeConfigFileClient()
    let bundledCLIURL = installEnvironment.bundledCLIURL()
    let installedCLIURL = installedCLIURL(
      homeDirectoryURL: installEnvironment.homeDirectoryURL(),
      installFileSystem: installFileSystem
    )
    let openCodeConfigURL = openCodeConfigURL(
      homeDirectoryURL: installEnvironment.homeDirectoryURL(),
      openCodeConfigFile: openCodeConfigFile
    )
    let openCodeMCPCommandPath = openCodeMCPCommandPath(
      configURL: openCodeConfigURL,
      openCodeConfigFile: openCodeConfigFile
    )

    return WorkspaceInstallStatus(
      bundledCLIURL: bundledCLIURL,
      installedCLIURL: installedCLIURL,
      openCodeConfigURL: openCodeConfigURL,
      openCodeMCPCommandPath: openCodeMCPCommandPath
    )
  }

  func installOrUpdateCLI() -> StudioInstallResult {
    let installEnvironment = installEnvironmentStatus()
    let installFileSystem = installFileSystemClient()
    guard let bundledCLIURL = installEnvironment.bundledCLIURL() else {
      return StudioInstallResult(
        outcome: .failed,
        title: "CLI Install Failed",
        message: "PersonaKit Studio could not find its bundled CLI executable."
      )
    }
    guard let bundledSupportBundleURL = installEnvironment.bundledCLISupportBundleURL() else {
      return StudioInstallResult(
        outcome: .failed,
        title: "CLI Install Failed",
        message: "PersonaKit Studio could not find its bundled CLI support bundle."
      )
    }

    let targetURL = cliInstallURL(homeDirectoryURL: installEnvironment.homeDirectoryURL())
    let supportBundleTargetURL = cliSupportBundleInstallURL(
      homeDirectoryURL: installEnvironment.homeDirectoryURL()
    )
    let hadInstalledBinary = installFileSystem.fileExists(at: targetURL)
    let hadInstalledSupportBundle = installFileSystem.fileExists(at: supportBundleTargetURL)
    let hadInstalledCLI = hadInstalledBinary || hadInstalledSupportBundle

    do {
      try installFileSystem.createDirectory(at: targetURL.deletingLastPathComponent())

      let temporaryURL = targetURL.deletingLastPathComponent()
        .appendingPathComponent(".personakit-install.tmp")
      let temporarySupportBundleURL = targetURL.deletingLastPathComponent()
        .appendingPathComponent(".personakit-install.bundle.tmp")

      if installFileSystem.fileExists(at: temporaryURL) {
        try installFileSystem.removeItem(at: temporaryURL)
      }

      if installFileSystem.fileExists(at: temporarySupportBundleURL) {
        try installFileSystem.removeItem(at: temporarySupportBundleURL)
      }

      try installFileSystem.copyItem(
        at: bundledCLIURL,
        to: temporaryURL
      )
      try installFileSystem.copyItem(
        at: bundledSupportBundleURL,
        to: temporarySupportBundleURL
      )
      try installFileSystem.setExecutableFile(at: temporaryURL)

      if hadInstalledBinary {
        try installFileSystem.replaceItem(
          at: targetURL,
          with: temporaryURL
        )
      } else {
        try installFileSystem.moveItem(
          at: temporaryURL,
          to: targetURL
        )
      }

      if hadInstalledSupportBundle {
        try installFileSystem.replaceItem(
          at: supportBundleTargetURL,
          with: temporarySupportBundleURL
        )
      } else {
        try installFileSystem.moveItem(
          at: temporarySupportBundleURL,
          to: supportBundleTargetURL
        )
      }
    } catch {
      return StudioInstallResult(
        outcome: .failed,
        title: "CLI Install Failed",
        message: "PersonaKit Studio could not install the CLI at \(targetURL.path()): \(error.localizedDescription)"
      )
    }

    let outcome: StudioInstallOutcome = hadInstalledCLI ? .updated : .installed
    let title = hadInstalledCLI ? "CLI Updated" : "CLI Installed"
    let installDirectory = targetURL.deletingLastPathComponent().path()
    let message = """
      PersonaKit CLI is available at \(targetURL.path()).

      If needed, add \(installDirectory) to PATH.
      """

    return StudioInstallResult(
      outcome: outcome,
      title: title,
      message: message
    )
  }

  func installOrUpdateOpenCodeMCP() -> StudioInstallResult {
    let installEnvironment = installEnvironmentStatus()
    let openCodeConfigFile = openCodeConfigFileClient()
    let status = refreshInstallStatus()
    guard
      let resolvedCLIURL = status.installedCLIURL
        ?? installEnvironment.bundledCLIURL()
    else {
      return StudioInstallResult(
        outcome: .failed,
        title: "MCP Install Failed",
        message: "PersonaKit Studio could not find a CLI executable to register with OpenCode."
      )
    }

    let configURL = status.openCodeConfigURL
    let mcpEntry = makeOpenCodeMCPEntry(commandPath: resolvedCLIURL.path())
    let manualSnippet = makeManualMergeSnippet(commandPath: resolvedCLIURL.path())
    let hadExistingEntry = status.openCodeMCPCommandPath != nil
    let configExists = openCodeConfigFile.configExists(at: configURL)

    if configExists, configURL.lastPathComponent == Self.openCodeJSONCFilename {
      return StudioInstallResult(
        outcome: .failed,
        title: "MCP Install Failed",
        message: """
          PersonaKit Studio found an existing JSONC config at \(configURL.path()).

          To avoid stripping comments or trailing commas, merge this JSON manually:
          \(manualSnippet)
          """
      )
    }

    do {
      try installFileSystemClient().createDirectory(
        at: configURL.deletingLastPathComponent()
      )

      var configuration = try readOpenCodeConfiguration(
        configURL: configURL,
        openCodeConfigFile: openCodeConfigFile
      )

      if configuration["$schema"] == nil {
        configuration["$schema"] = Self.openCodeSchemaURL
      }

      let existingMCP = configuration["mcp"]
      guard existingMCP == nil || existingMCP is [String: Any] else {
        return StudioInstallResult(
          outcome: .failed,
          title: "MCP Install Failed",
          message: """
            PersonaKit Studio could not update \(configURL.path()) because the existing `mcp` value is not an object.

            Merge this JSON manually:
            \(manualSnippet)
            """
        )
      }

      var mcpConfiguration = configuration["mcp"] as? [String: Any] ?? [:]
      mcpConfiguration[Self.personakitMCPName] = mcpEntry
      configuration["mcp"] = mcpConfiguration

      let encodedConfiguration = try JSONSerialization.data(
        withJSONObject: configuration,
        options: [.prettyPrinted, .sortedKeys]
      )
      try openCodeConfigFile.writeConfigData(
        encodedConfiguration,
        to: configURL
      )
    } catch let error as OpenCodeConfigError {
      return StudioInstallResult(
        outcome: .failed,
        title: "MCP Install Failed",
        message: """
          PersonaKit Studio could not update \(configURL.path()) because the existing config could not be parsed.

          Merge this JSON manually:
          \(manualSnippet)

          Details: \(error.localizedDescription)
          """
      )
    } catch {
      return StudioInstallResult(
        outcome: .failed,
        title: "MCP Install Failed",
        message: "PersonaKit Studio could not update \(configURL.path()): \(error.localizedDescription)"
      )
    }

    let outcome: StudioInstallOutcome = hadExistingEntry ? .updated : .installed
    let title = hadExistingEntry ? "MCP Updated" : "MCP Installed"

    return StudioInstallResult(
      outcome: outcome,
      title: title,
      message: """
        OpenCode will launch PersonaKit MCP from \(resolvedCLIURL.path()).

        Updated config: \(configURL.path())
        """
    )
  }

  private func cliInstallURL(homeDirectoryURL: URL) -> URL {
    homeDirectoryURL
      .appendingPathComponent(Self.cliInstallSubpath)
      .standardizedFileURL
  }

  private func cliSupportBundleInstallURL(homeDirectoryURL: URL) -> URL {
    cliInstallURL(homeDirectoryURL: homeDirectoryURL)
      .deletingLastPathComponent()
      .appendingPathComponent(Self.cliSupportBundleName)
      .standardizedFileURL
  }

  private func installedCLIURL(
    homeDirectoryURL: URL,
    installFileSystem: any WorkspaceInstallFileOperating
  ) -> URL? {
    let url = cliInstallURL(homeDirectoryURL: homeDirectoryURL)
    let supportBundleURL = cliSupportBundleInstallURL(homeDirectoryURL: homeDirectoryURL)

    guard
      installFileSystem.isExecutableFile(at: url),
      installFileSystem.fileExists(at: supportBundleURL)
    else {
      return nil
    }

    return url
  }

  private func openCodeConfigURL(
    homeDirectoryURL: URL,
    openCodeConfigFile: any OpenCodeConfigurationFileAccessing
  ) -> URL {
    let directoryURL =
      homeDirectoryURL
      .appendingPathComponent(Self.openCodeDirectorySubpath)
      .standardizedFileURL
    let jsoncURL = directoryURL.appendingPathComponent(Self.openCodeJSONCFilename)
    let jsonURL = directoryURL.appendingPathComponent(Self.openCodeJSONFilename)

    if openCodeConfigFile.configExists(at: jsoncURL) {
      return jsoncURL
    }

    if openCodeConfigFile.configExists(at: jsonURL) {
      return jsonURL
    }

    return jsonURL
  }

  private func openCodeMCPCommandPath(
    configURL: URL,
    openCodeConfigFile: any OpenCodeConfigurationFileAccessing
  ) -> String? {
    guard
      let configuration = try? readOpenCodeConfiguration(
        configURL: configURL,
        openCodeConfigFile: openCodeConfigFile
      ),
      let mcp = configuration["mcp"] as? [String: Any],
      let personakit = mcp[Self.personakitMCPName] as? [String: Any],
      let command = personakit["command"] as? [String],
      let firstPath = command.first
    else {
      return nil
    }

    return firstPath
  }

  private func makeOpenCodeMCPEntry(commandPath: String) -> [String: Any] {
    [
      "command": [commandPath, "mcp"],
      "enabled": true,
      "type": "local",
    ]
  }

  private func makeManualMergeSnippet(commandPath: String) -> String {
    let object: [String: Any] = [
      "$schema": Self.openCodeSchemaURL,
      "mcp": [
        Self.personakitMCPName: makeOpenCodeMCPEntry(commandPath: commandPath)
      ],
    ]

    let data = try? JSONSerialization.data(
      withJSONObject: object,
      options: [.prettyPrinted, .sortedKeys]
    )

    return data.flatMap {
      String(data: $0, encoding: .utf8)
    }
      ?? """
      {
        "$schema" : "\(Self.openCodeSchemaURL)",
        "mcp" : {
          "\(Self.personakitMCPName)" : {
            "command" : [
              "\(commandPath)",
              "mcp"
            ],
            "enabled" : true,
            "type" : "local"
          }
        }
      }
      """
  }

  private func readOpenCodeConfiguration(
    configURL: URL,
    openCodeConfigFile: any OpenCodeConfigurationFileAccessing
  ) throws -> [String: Any] {
    guard openCodeConfigFile.configExists(at: configURL) else {
      return [:]
    }

    let data = try openCodeConfigFile.readConfigData(at: configURL)
    let rawText = String(decoding: data, as: UTF8.self)
    let normalizedText = try normalizeJSONC(rawText)

    guard let normalizedData = normalizedText.data(using: .utf8) else {
      throw OpenCodeConfigError.invalidJSON
    }

    do {
      guard
        let object = try JSONSerialization.jsonObject(with: normalizedData) as? [String: Any]
      else {
        throw OpenCodeConfigError.invalidJSON
      }

      return object
    } catch {
      throw OpenCodeConfigError.invalidJSON
    }
  }

  private func normalizeJSONC(_ input: String) throws -> String {
    let commentFree = try stripJSONCComments(from: input)
    return stripTrailingCommas(from: commentFree)
  }

  private func stripJSONCComments(from input: String) throws -> String {
    enum State {
      case normal
      case string
      case lineComment
      case blockComment
    }

    var state = State.normal
    let characters = Array(input)
    var index = 0
    var output = ""
    var previousWasEscape = false
    var blockCommentClosed = true

    while index < characters.count {
      let character = characters[index]

      switch state {
      case .normal:
        if character == "\"" {
          output.append(character)
          state = .string
        } else if character == "/" {
          guard index + 1 < characters.count else {
            output.append(character)
            index += 1
            continue
          }

          let nextCharacter = characters[index + 1]

          if nextCharacter == "/" {
            state = .lineComment
            index += 1
          } else if nextCharacter == "*" {
            state = .blockComment
            blockCommentClosed = false
            index += 1
          } else {
            output.append(character)
          }
        } else {
          output.append(character)
        }

      case .string:
        output.append(character)

        if previousWasEscape {
          previousWasEscape = false
        } else if character == "\\" {
          previousWasEscape = true
        } else if character == "\"" {
          state = .normal
        }

      case .lineComment:
        if character == "\n" {
          output.append(character)
          state = .normal
        }

      case .blockComment:
        if character == "*", index + 1 < characters.count {
          let nextCharacter = characters[index + 1]

          if nextCharacter == "/" {
            state = .normal
            blockCommentClosed = true
            index += 1
          }
        }
      }

      index += 1
    }

    if state == .blockComment && !blockCommentClosed {
      throw OpenCodeConfigError.invalidJSON
    }

    return output
  }

  private func stripTrailingCommas(from input: String) -> String {
    var output = ""
    var previousNonWhitespaceCharacters: [Character] = []
    var isInsideString = false
    var previousWasEscape = false

    for character in input {
      if isInsideString {
        output.append(character)

        if previousWasEscape {
          previousWasEscape = false
        } else if character == "\\" {
          previousWasEscape = true
        } else if character == "\"" {
          isInsideString = false
        }

        continue
      }

      if character == "\"" {
        isInsideString = true
        output.append(character)
        previousNonWhitespaceCharacters.append(character)
        continue
      }

      if character == "}" || character == "]" {
        while previousNonWhitespaceCharacters.last == "," {
          previousNonWhitespaceCharacters.removeLast()

          while let lastCharacter = output.last, lastCharacter.isWhitespace {
            output.removeLast()
          }

          if output.last == "," {
            output.removeLast()
          }

          while let lastCharacter = output.last, lastCharacter.isWhitespace {
            output.removeLast()
          }
        }
      }

      output.append(character)

      if character.isWhitespace {
        continue
      }

      previousNonWhitespaceCharacters.append(character)
    }

    return output
  }
}

private enum OpenCodeConfigError: LocalizedError {
  case invalidJSON

  var errorDescription: String? {
    switch self {
    case .invalidJSON:
      return "The file is not valid JSON or JSONC."
    }
  }
}
