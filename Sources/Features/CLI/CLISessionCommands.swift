import ArgumentParser
import ContextCore
import Foundation

struct ReferenceTriggerOptions: ParsableArguments {
  @Option(
    name: .customLong("target-path"),
    help: "Target file path used when evaluating available references."
  )
  var targetPaths: [String] = []

  @Option(
    name: .customLong("reference-tag"),
    help: "Reference tag used when evaluating available references."
  )
  var referenceTags: [String] = []
}

/// Resolves and prints the structured PersonaKit operating contract.
struct ContractCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "contract",
    abstract: "Resolve the structured PersonaKit operating contract."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @Option(name: .customLong("check-skills"), help: "Comma-separated skill ids to verify.")
  var checkSkills: String?

  mutating func validate() throws {
    try session.validate(mode: .contract)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    let requestedSkillIds = SessionSelection.parseCSV(checkSkills)
    let result: SessionContractResult

    do {
      if let sessionId = session.sessionId {
        let sessionFile = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)
        result = try SessionContractResolver.resolve(
          scopes: scopes,
          session: sessionFile,
          requestedSkillIds: requestedSkillIds
        )
      } else {
        result = try SessionContractResolver.resolve(
          scopes: scopes,
          personaId: session.personaId ?? "",
          directiveId: session.directiveId,
          kitOverrides: session.directiveId == nil ? [] : session.kitIds,
          requestedSkillIds: requestedSkillIds
        )
      }
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(SessionContractResolver.snapshot(from: result))

    guard let output = String(data: data, encoding: .utf8) else {
      throw CLIError.failure("Failed to encode contract output.")
    }

    print(output)
  }
}

/// Exports a resolved PersonaKit session as text.
struct ExportCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "export",
    abstract: "Export a session prompt."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @OptionGroup
  var referenceTriggers: ReferenceTriggerOptions

  @Option(name: .customLong("output"), help: "Write output to a file path.")
  var outputPath: String?

  mutating func validate() throws {
    try session.validate(mode: .export)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    do {
      let sessionInput = try CLIHelpers.resolveSessionInput(
        from: session,
        scopes: scopes
      )
      let output = try SessionExporter.export(
        scopes: scopes,
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides,
        targetPaths: referenceTriggers.targetPaths,
        referenceTags: referenceTriggers.referenceTags
      )
      if let outputPath {
        let outputURL = RootPathResolver().resolve(path: outputPath)
        try AtomicFileWriter().write(contents: output, to: outputURL)
      } else {
        print(output)
      }
    } catch let error as ExportError {
      var stderrStream = StandardError()
      switch error {
      case .validationFailed(let result):
        stderrStream.write(result.summary + "\n")
        for validationError in result.errors {
          stderrStream.write(validationError.lineDescription() + "\n")
        }
      case .resolutionFailed(let resolutionError):
        for resolutionError in resolutionError.errors {
          stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
        }
      case .readFailed(let message):
        stderrStream.write("Error: \(message)\n")
      }
      throw ExitCode.failure
    }
  }
}

/// Resolves triggered workflow references for inspection/debugging.
struct ResolveReferencesCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "resolve-references",
    abstract: "Resolve triggered references for a session prompt."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @OptionGroup
  var referenceTriggers: ReferenceTriggerOptions

  mutating func validate() throws {
    try session.validate(mode: .resolveReferences)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)

    do {
      let sessionInput = try CLIHelpers.resolveSessionInput(
        from: session,
        scopes: scopes
      )
      let result = try WorkflowReferenceResolver.resolve(
        scopes: scopes,
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides,
        input: ReferenceSelectionInput(
          targetPaths: referenceTriggers.targetPaths,
          referenceTags: referenceTriggers.referenceTags
        )
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(result)

      guard let output = String(data: data, encoding: .utf8) else {
        throw CLIError.failure("Failed to encode reference resolution output.")
      }

      print(output)
    } catch let error as ReferenceLookupError {
      var stderrStream = StandardError()
      switch error {
      case .validationFailed(let result):
        stderrStream.write(result.summary + "\n")
        for validationError in result.errors {
          stderrStream.write(validationError.lineDescription() + "\n")
        }
      case .resolutionFailed(let resolutionError):
        for resolutionError in resolutionError.errors {
          stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
        }
      case .referenceResolutionFailed(let resolutionError):
        stderrStream.write("Error: \(resolutionError.message)\n")
      }
      throw ExitCode.failure
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    }
  }
}

/// Renders a resolved PersonaKit session graph.
struct GraphCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "graph",
    abstract: "Render a session graph."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  mutating func validate() throws {
    try session.validate(mode: .graph)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    do {
      let sessionInput = try CLIHelpers.resolveSessionInput(
        from: session,
        scopes: scopes
      )
      let registry = try Registry.load(scopes: scopes)
      let definition = SessionDefinition(
        personaId: sessionInput.personaId,
        directiveId: sessionInput.directiveId,
        kitOverrides: sessionInput.kitOverrides.isEmpty ? nil : sessionInput.kitOverrides
      )
      let resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
      let output = GraphPrinter.render(
        resolvedSession: resolved,
        kitOverrides: sessionInput.kitOverrides
      )
      print(output)
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    }
  }
}
