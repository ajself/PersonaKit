import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import Foundation

struct CreateReferenceData {
  let personaIDs: Set<String>
  let directiveIDs: Set<String>
  let kitIDs: Set<String>
  let skillIDs: Set<String>
  let essentialIDs: Set<String>
}

struct CreateResultEnvelope: Encodable {
  let result: WorkspaceCreationResult
  let renderedContent: String?
}

struct CreateFailureEnvelope: Encodable {
  let error: String
}

struct CreatePrompter {
  private let io: CLIInteractiveIO

  init(io: CLIInteractiveIO = CLIEnvironment.current.interactiveIO) {
    self.io = io
  }

  var isInteractive: Bool {
    io.isInteractive()
  }

  func promptRequired(
    _ label: String,
    hint: String? = nil
  ) -> String {
    while true {
      let value = promptOptional(label, hint: hint)
      if !value.isEmpty {
        return value
      }
    }
  }

  func promptOptional(
    _ label: String,
    hint: String? = nil
  ) -> String {
    if let hint {
      print(hint)
    }
    CreateCommandHelpers.writePrompt("\(label): ")
    return CreateCommandHelpers.trimmed(io.readLine())
  }

  func promptSuggestedID(
    label: String,
    source: String
  ) -> String {
    let suggested = WorkspaceEntityIDSuggester.suggestedID(from: source)
    if !suggested.isEmpty {
      print("Suggested id: \(suggested)")
    }
    CreateCommandHelpers.writePrompt("\(label)\(suggested.isEmpty ? "" : " [\(suggested)]"): ")
    let response = CreateCommandHelpers.normalizedID(io.readLine())
    return response.isEmpty ? suggested : response
  }

  func promptSuggestedExistingID(
    label: String,
    suggestedID: String
  ) -> String {
    if !suggestedID.isEmpty {
      print("Suggested id: \(suggestedID)")
    }
    CreateCommandHelpers.writePrompt("\(label)\(suggestedID.isEmpty ? "" : " [\(suggestedID)]"): ")
    let response = CreateCommandHelpers.normalizedID(io.readLine())
    return response.isEmpty ? suggestedID : response
  }

  func promptCSVIfNeeded(
    values: [String],
    label: String,
    hint: String?
  ) -> [String] {
    let existing = CreateCommandHelpers.trimmedItems(values)
    guard existing.isEmpty, isInteractive else {
      return existing
    }

    let response = promptOptional(label, hint: hint)
    return CreateCommandHelpers.parseCSV(response)
  }

  func promptRepeatedText(_ label: String) -> [String] {
    guard isInteractive else {
      return []
    }

    var values: [String] = []

    while true {
      CreateCommandHelpers.writePrompt("\(label) (blank to finish): ")
      let value = CreateCommandHelpers.trimmed(io.readLine())

      if value.isEmpty {
        break
      }

      values.append(value)
    }

    return values
  }

  func promptYesNo(
    label: String,
    defaultValue: Bool
  ) -> Bool {
    guard isInteractive else {
      return defaultValue
    }

    while true {
      let suffix = defaultValue ? "[Y/n]" : "[y/N]"
      CreateCommandHelpers.writePrompt("\(label) \(suffix): ")
      let response = CreateCommandHelpers.trimmed(io.readLine()).lowercased()

      if response.isEmpty {
        return defaultValue
      }

      switch response {
      case "y", "yes":
        return true
      case "n", "no":
        return false
      default:
        continue
      }
    }
  }

  func promptRiskLevel(defaultValue: String) throws -> String {
    while true {
      CreateCommandHelpers.writePrompt("Risk level [\(defaultValue)] (low|medium|high): ")
      let response = CreateCommandHelpers.trimmed(io.readLine())
      let value = response.isEmpty ? defaultValue : response

      do {
        try CreateCommandHelpers.validateRiskLevel(value)
        return value
      } catch {
        continue
      }
    }
  }

  func confirmWrite(
    entityType: String,
    entityID: String,
    destinationURL: URL,
    force: Bool
  ) throws {
    guard isInteractive else {
      return
    }

    print("Ready to create \(entityType) \"\(entityID)\" at \(destinationURL.path)")
    if force {
      print("Existing file will be overwritten if present.")
    }

    guard promptYesNo(label: "Write file now", defaultValue: true) else {
      throw CleanExit.message("Creation cancelled.")
    }
  }
}

enum CreateCommandHelpers {
  static func runWithJSONErrors(
    jsonOutput: Bool,
    _ body: () throws -> Void
  ) throws {
    do {
      try body()
    } catch let error as CleanExit {
      throw error
    } catch {
      if jsonOutput {
        emitJSON(CreateFailureEnvelope(error: errorMessage(for: error)))
        throw ExitCode.failure
      }

      throw error
    }
  }

  static func errorMessage(for error: Error) -> String {
    if let validationError = error as? ArgumentParser.ValidationError {
      return validationError.message
    }

    if let localizedError = error as? LocalizedError,
      let errorDescription = localizedError.errorDescription
    {
      return errorDescription
    }

    return error.localizedDescription
  }

  static func resolveWritableRoot(rootPath: String?) throws -> URL {
    do {
      let explicitRootURL = rootPath.map { RootPathResolver().resolve(path: $0) }
      return try WorkspaceWritableRootResolver(
        scopeRootResolver: CLIEnvironment.current.scopeRootResolver
      )
      .resolveWritableRoot(explicitRootURL: explicitRootURL)
    } catch let error as WorkspaceSnapshotBuildError {
      throw ArgumentParser.ValidationError(error.message)
    }
  }

  static func loadReferences(rootURL: URL) throws -> CreateReferenceData {
    let scopes = resolveReferenceScopes(for: rootURL)

    let registry: Registry
    do {
      registry = try Registry.load(scopes: scopes)
    } catch let error as RegistryLoadError {
      let details = error.errors.map(CLIHelpers.formatRegistryError).joined(separator: "\n")
      throw CLIError.failure(details)
    }

    let essentials = try discoverEssentialIDs(rootURL: rootURL)
    return CreateReferenceData(
      personaIDs: Set(registry.personas.map(\.id)),
      directiveIDs: Set(registry.directives.map(\.id)),
      kitIDs: Set(registry.kits.map(\.id)),
      skillIDs: Set(registry.skills.map(\.id)),
      essentialIDs: essentials
    )
  }

  static func requireFields(
    _ fields: [String?],
    example: String,
    interactive: Bool
  ) throws {
    let missing = fields.compactMap { $0 }

    guard !missing.isEmpty else {
      return
    }

    guard !interactive else {
      throw CLIError.failure("Missing required fields: \(missing.joined(separator: ", ")).")
    }

    throw ArgumentParser.ValidationError(
      "Missing required fields: \(missing.joined(separator: ", ")). Example: \(example)"
    )
  }

  static func prepareWrite(
    destinationURL: URL,
    force: Bool
  ) throws -> Bool {
    let exists = FileManager.default.fileExists(atPath: destinationURL.path)

    if exists, !force {
      throw CLIError.failure(
        "Refusing to overwrite existing file: \(destinationURL.path). Use --force to overwrite."
      )
    }

    return exists
  }

  static func completeCreation(
    entityType: String,
    entityID: String,
    destinationURL: URL,
    warnings: [String],
    renderedContent: String,
    dryRun: Bool,
    force: Bool,
    jsonOutput: Bool,
    prompter: CreatePrompter,
    writeAction: () throws -> Void
  ) throws {
    let overwrote = FileManager.default.fileExists(atPath: destinationURL.path)

    if !dryRun {
      _ = try prepareWrite(
        destinationURL: destinationURL,
        force: force
      )

      try prompter.confirmWrite(
        entityType: entityType,
        entityID: entityID,
        destinationURL: destinationURL,
        force: force
      )

      try writeAction()
    }

    let result = WorkspaceCreationResult(
      entityType: entityType,
      entityID: entityID,
      destinationPath: destinationURL.path,
      warnings: warnings,
      overwroteExisting: overwrote,
      dryRun: dryRun
    )
    emitSuccess(
      result: result,
      renderedContent: dryRun ? renderedContent : nil,
      jsonOutput: jsonOutput
    )
  }

  static func emitSuccess(
    result: WorkspaceCreationResult,
    renderedContent: String?,
    jsonOutput: Bool
  ) {
    if jsonOutput {
      emitJSON(
        CreateResultEnvelope(
          result: result,
          renderedContent: renderedContent
        )
      )
      return
    }

    if result.dryRun {
      print("Dry run for \(result.entityType) \"\(result.entityID)\"")
      print("Destination: \(result.destinationPath)")
      if !result.warnings.isEmpty {
        for warning in result.warnings {
          print("Warning: \(warning)")
        }
      }
      if let renderedContent {
        print("")
        print(renderedContent, terminator: "")
      }
      return
    }

    print("Created \(result.entityType) \"\(result.entityID)\" at \(result.destinationPath)")
    if result.overwroteExisting {
      print("Overwrote existing file.")
    }
    for warning in result.warnings {
      print("Warning: \(warning)")
    }
    if let rootPath = inferredRootPath(fromDestinationPath: result.destinationPath) {
      print("Next: personakit validate --root \(rootPath)")
    }
  }

  static func emitJSON<T: Encodable>(_ value: T) {
    do {
      print(try WorkspaceAuthoringJSON.encode(value), terminator: "")
    } catch {
      var stderrStream = StandardError()
      stderrStream.write("Error: \(error.localizedDescription)\n")
    }
  }

  static func referenceHint(
    label: String,
    values: Set<String>
  ) -> String? {
    guard !values.isEmpty else {
      return nil
    }

    let sorted = values.sorted()
    let preview = sorted.prefix(8).joined(separator: ", ")

    if sorted.count > 8 {
      return "\(label): \(preview), ..."
    }

    return "\(label): \(preview)"
  }

  static func validateRiskLevel(_ value: String) throws {
    let normalized = trimmed(value).lowercased()

    switch normalized {
    case "low", "medium", "high":
      return
    default:
      throw CLIError.failure("Risk level must be one of: low, medium, high.")
    }
  }

  static func parseCSV(_ value: String?) -> [String] {
    guard let value else {
      return []
    }

    return
      value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  static func trimmed(_ value: String?) -> String {
    value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  static func trimmedItems(_ values: [String]) -> [String] {
    values
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  /// Inline marker that gates a `--step` for review while preserving its position.
  static let reviewStepMarker = "review:"

  /// Parses a `--step` value into an ordered directive step, honoring a leading
  /// `review:` marker that gates the step for review without moving it to the end.
  ///
  /// - Parameter raw: Raw step text, already trimmed of surrounding whitespace.
  /// - Returns: A step with `requiresReview` set when the marker is present, or
  ///   `nil` when the remaining text is empty.
  static func parseOrderedStep(_ raw: String) -> Directive.Step? {
    if raw.lowercased().hasPrefix(reviewStepMarker) {
      let text = String(raw.dropFirst(reviewStepMarker.count))
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return text.isEmpty ? nil : Directive.Step(text: text, requiresReview: true)
    }

    return Directive.Step(text: raw, requiresReview: nil)
  }

  static func normalizedID(_ value: String?) -> String {
    let trimmed = trimmed(value)

    guard !trimmed.isEmpty else {
      return ""
    }

    return WorkspaceEntityIDPolicy.normalized(trimmed)
  }

  static func writePrompt(_ value: String) {
    guard let data = value.data(using: .utf8) else {
      return
    }

    FileHandle.standardOutput.write(data)
  }

  static func inferredRootPath(fromDestinationPath path: String) -> String? {
    let fileURL = URL(fileURLWithPath: path)
    let parent = fileURL.deletingLastPathComponent()

    if parent.lastPathComponent == "Sessions" {
      return parent.deletingLastPathComponent().path
    }

    if parent.deletingLastPathComponent().lastPathComponent == "Packs" {
      return parent.deletingLastPathComponent().deletingLastPathComponent().path
    }

    return nil
  }

  private static func discoverEssentialIDs(rootURL: URL) throws -> Set<String> {
    let essentialsDirectory = rootURL.appendingPathComponent("Packs/essentials")
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: essentialsDirectory.path, isDirectory: &isDirectory) else {
      return []
    }

    guard isDirectory.boolValue else {
      throw CLIError.failure("Essentials path is not a directory: \(essentialsDirectory.path)")
    }

    let files = try FileManager.default.contentsOfDirectory(
      at: essentialsDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )

    return Set(
      files
        .filter { $0.lastPathComponent.hasSuffix(".md") }
        .map { $0.deletingPathExtension().lastPathComponent }
    )
    .union(builtInEssentialIDs)
  }

  private static func resolveReferenceScopes(
    for rootURL: URL
  ) -> ScopeSet {
    let standardizedRootURL = rootURL.standardizedFileURL
    let discovered = CLIEnvironment.current.scopeRootResolver.locate()

    if discovered?.globalScopeURL?.standardizedFileURL == standardizedRootURL {
      return ScopeSet(projectScopeURL: nil, globalScopeURL: standardizedRootURL)
    }

    let globalScopeURL = discovered?.globalScopeURL?.standardizedFileURL

    return ScopeSet(
      projectScopeURL: standardizedRootURL,
      globalScopeURL: globalScopeURL == standardizedRootURL ? nil : globalScopeURL
    )
  }

  private static let builtInEssentialIDs: Set<String> = [
    "persona-activation-contract",
    "skill-authorization-contract",
  ]
}
