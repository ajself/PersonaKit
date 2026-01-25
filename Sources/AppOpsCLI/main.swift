import AppOpsCore
import Dependencies
import Foundation
import PersonaKitCore
import PersonaKitResources

/// Inputs used to run AppOps and produce a report.
struct AppOpsEnvironment {
  let fileClient: FileClient
  let now: () -> Date
  let repoRoot: () throws -> URL
  let runCommand: ([String]) -> String?
  let builtInPackURLs: (URL) -> [URL]

  /// Live environment wired to the local file system and process runner.
  static func live() -> AppOpsEnvironment {
    let provider = DependencyProvider()
    return AppOpsEnvironment(
      fileClient: provider.fileClient,
      now: Date.init,
      repoRoot: { try AppOpsCLI.defaultRepoRoot() },
      runCommand: AppOpsCLI.defaultRunCommand,
      builtInPackURLs: { repoRoot in
        AppOpsCLI.defaultBuiltInPackURLs(repoRoot: repoRoot)
      }
    )
  }
}

/// Output details captured after a successful AppOps run.
struct AppOpsRunResult {
  let outputRoot: URL
  let report: AppOpsReport
}

private struct DependencyProvider {
  @Dependency(\.fileClient)
  var fileClient
}

/// Command-line entry point for generating AppOps reports.
@main
enum AppOpsCLI {
  private struct ParsedArgs {
    var values: [String: String] = [:]
    var flags: Set<String> = []

    func value(for key: String) -> String? {
      values[key]
    }

    func hasFlag(_ key: String) -> Bool {
      flags.contains(key)
    }
  }

  private struct ReloadSnapshot {
    let builtInSets: [PersonaSet]
    let builtInDiagnostics: [Diagnostic]
    let userSets: [PersonaSet]
    let userDiagnostics: [Diagnostic]
    let mergeResult: (personas: [String: Persona], diagnostics: [Diagnostic])
    let resolved: PersonaResolver.ResolutionResult
    let metrics: ReloadMetrics
  }

  static func main() {
    do {
      _ = try run(arguments: Array(CommandLine.arguments.dropFirst()), environment: .live())
    } catch {
      fputs("Error: \(error)\n", stderr)
      exit(1)
    }
  }

  /// Runs the CLI with injected dependencies for testability.
  static func run(arguments: [String], environment: AppOpsEnvironment) throws -> AppOpsRunResult {
    let parsed = parseArgs(arguments)
    if parsed.hasFlag("help") {
      printUsage()
      return AppOpsRunResult(outputRoot: URL(fileURLWithPath: "/"), report: emptyReport())
    }

    let fileClient = environment.fileClient
    let repoRoot = try environment.repoRoot()
    let outDir = resolvePath(parsed.value(for: "out-dir") ?? "Artifacts", relativeTo: repoRoot)
    let includeUserPacks = !parsed.hasFlag("no-user-packs")
    let builtInURLs = environment.builtInPackURLs(repoRoot)
    guard !builtInURLs.isEmpty else {
      throw AppOpsError("Built-in packs not found. Fix: ensure PersonaKitResources are available.")
    }

    let importSource = resolvePath(
      parsed.value(for: "import-source") ?? "Examples/personakit.pack.json",
      relativeTo: repoRoot
    )
    let diffLeft = resolvePath(
      parsed.value(for: "diff-left") ?? builtInURLs[0].path,
      relativeTo: repoRoot
    )
    let diffRight = resolvePath(
      parsed.value(for: "diff-right") ?? "Examples/personakit.pack.json",
      relativeTo: repoRoot
    )

    guard fileClient.fileExists(importSource) else {
      throw AppOpsError("Import source not found: \(importSource.path)")
    }
    guard fileClient.fileExists(diffLeft) else {
      throw AppOpsError("Diff-left pack not found: \(diffLeft.path)")
    }
    guard fileClient.fileExists(diffRight) else {
      throw AppOpsError("Diff-right pack not found: \(diffRight.path)")
    }

    let timestamp = isoTimestampUTC(environment.now())
    let outputRoot = outDir.appendingPathComponent("appops-\(timestamp)", isDirectory: true)
    try fileClient.createDirectory(outputRoot, true)

    let reloadSnapshot = try runReload(
      repoRoot: repoRoot,
      builtInURLs: builtInURLs,
      includeUserPacks: includeUserPacks,
      fileClient: fileClient
    )

    let composeMetrics = measureCompose(resolved: reloadSnapshot.resolved)
    let diffMetrics = try measureDiff(left: diffLeft, right: diffRight)
    let importMetrics = try measureImport(
      selection: importSource,
      destinationRoot: outputRoot.appendingPathComponent("import", isDirectory: true),
      fileClient: fileClient
    )

    let exportMetrics = try measureExport(
      sets: reloadSnapshot.builtInSets + reloadSnapshot.userSets,
      outputRoot: outputRoot.appendingPathComponent("export", isDirectory: true),
      fileClient: fileClient
    )

    let report = AppOpsReport(
      schemaVersion: 1,
      run: RunMetadata(
        timestampUTC: timestamp,
        repoRoot: repoRoot.path,
        outputRoot: outputRoot.path,
        gitSha: environment.runCommand(["git", "rev-parse", "HEAD"]) ?? "unknown"
      ),
      environment: EnvironmentInfo(
        macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        swiftVersion: environment.runCommand(["swift", "--version"]) ?? "unknown",
        xcodeVersion: environment.runCommand(["xcodebuild", "-version"]) ?? "unknown"
      ),
      inputs: InputConfig(
        builtInSources: builtInURLs.map(\.path),
        userPacksRoot: includeUserPacks
          ? PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs.path
          : nil,
        includeUserPacks: includeUserPacks,
        importSource: importSource.path,
        diffLeft: diffLeft.path,
        diffRight: diffRight.path
      ),
      reload: reloadSnapshot.metrics,
      compose: composeMetrics,
      diff: diffMetrics,
      importMetrics: importMetrics,
      exportMetrics: exportMetrics
    )

    let jsonURL = outputRoot.appendingPathComponent("report.json")
    let markdownURL = outputRoot.appendingPathComponent("REPORT.md")
    try writeReport(report, jsonURL: jsonURL, markdownURL: markdownURL, fileClient: fileClient)

    print("Report written to:")
    print("- \(markdownURL.path)")
    print("- \(jsonURL.path)")
    return AppOpsRunResult(outputRoot: outputRoot, report: report)
  }

  private static func runReload(
    repoRoot: URL,
    builtInURLs: [URL],
    includeUserPacks: Bool,
    fileClient: FileClient
  ) throws -> ReloadSnapshot {
    let (builtIn, builtInDuration) = measure {
      loadBuiltInSets(urls: builtInURLs)
    }

    let (userSets, userDiagnostics, userDuration): ([PersonaSet], [Diagnostic], Double)
    if includeUserPacks {
      let (loaded, duration) = measure {
        loadUserSets(fileClient: fileClient)
      }
      userSets = loaded.sets
      userDiagnostics = loaded.diagnostics
      userDuration = duration
    } else {
      userSets = []
      userDiagnostics = []
      userDuration = 0
    }

    let combined = builtIn.sets + userSets
    let (mergeResult, mergeDuration) = measure {
      PersonaResolver.mergeSets(combined)
    }

    let (resolved, resolveDuration) = measure {
      PersonaResolver.resolveAll(from: mergeResult.personas)
    }

    let totalDiagnostics =
      builtIn.diagnostics.count
      + userDiagnostics.count
      + mergeResult.diagnostics.count
      + resolved.diagnostics.count

    let reloadMetrics = ReloadMetrics(
      totalDurationSeconds: builtInDuration + userDuration + mergeDuration + resolveDuration,
      builtIn: LoadMetrics(
        durationSeconds: builtInDuration,
        packCount: builtIn.sets.count,
        personaCount: builtIn.sets.reduce(0) { $0 + $1.personas.count },
        diagnosticsCount: builtIn.diagnostics.count
      ),
      userPacks: includeUserPacks
        ? LoadMetrics(
          durationSeconds: userDuration,
          packCount: userSets.count,
          personaCount: userSets.reduce(0) { $0 + $1.personas.count },
          diagnosticsCount: userDiagnostics.count
        )
        : nil,
      merge: MergeMetrics(
        durationSeconds: mergeDuration,
        personaCount: mergeResult.personas.count,
        diagnosticsCount: mergeResult.diagnostics.count
      ),
      resolve: ResolveMetrics(
        durationSeconds: resolveDuration,
        personaCount: resolved.personasByID.count,
        diagnosticsCount: resolved.diagnostics.count
      ),
      totalPacks: builtIn.sets.count + userSets.count,
      totalPersonas: mergeResult.personas.count,
      diagnosticsCount: totalDiagnostics
    )

    return ReloadSnapshot(
      builtInSets: builtIn.sets,
      builtInDiagnostics: builtIn.diagnostics,
      userSets: userSets,
      userDiagnostics: userDiagnostics,
      mergeResult: mergeResult,
      resolved: resolved,
      metrics: reloadMetrics
    )
  }

  private static func loadBuiltInSets(
    urls: [URL]
  ) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []
    for url in urls {
      switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
      case .success(let set): sets.append(set)
      case .failure(let error): diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return (sets, diagnostics)
  }

  private static func loadUserSets(
    fileClient: FileClient
  ) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    let packsRoot = PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs
    guard fileClient.fileExists(packsRoot) else {
      return ([], [])
    }
    let loaded = UserPackLoader.load(in: packsRoot, fileClient: fileClient)
    return (loaded.packs.map { $0.set }, loaded.diagnostics)
  }

  private static func measureCompose(
    resolved: PersonaResolver.ResolutionResult
  ) -> ComposeMetrics {
    let personas = resolved.personasByID.keys.sorted().compactMap {
      resolved.personasByID[$0]?.persona
    }
    let (result, duration) = measure {
      var promptBytes = 0
      var jsonBytes = 0
      for persona in personas {
        let sections = sampleSections(for: persona)
        let prompt = PersonaOutputRenderer.prompt(persona: persona, sections: sections)
        promptBytes += prompt.utf8.count
        if let json = PersonaOutputRenderer.resolvedJSON(persona: persona, prettyPrinted: true) {
          jsonBytes += json.utf8.count
        }
      }
      return (promptBytes: promptBytes, jsonBytes: jsonBytes)
    }
    return ComposeMetrics(
      durationSeconds: duration,
      personaCount: personas.count,
      promptBytesTotal: result.promptBytes,
      jsonBytesTotal: result.jsonBytes
    )
  }

  private static func measureDiff(left: URL, right: URL) throws -> DiffMetrics {
    let leftSet = try loadSet(url: left, sourceKind: .project)
    let rightSet = try loadSet(url: right, sourceKind: .project)

    let (diff, duration) = measure {
      let leftRecords = diffRecords(for: leftSet)
      let rightRecords = diffRecords(for: rightSet)
      return PackDiffBuilder.diff(left: leftRecords, right: rightRecords)
    }

    return DiffMetrics(
      durationSeconds: duration,
      leftPersonaCount: leftSet.personas.count,
      rightPersonaCount: rightSet.personas.count,
      addedCount: diff.added.count,
      removedCount: diff.removed.count,
      modifiedCount: diff.modified.count
    )
  }

  private static func measureImport(
    selection: URL,
    destinationRoot: URL,
    fileClient: FileClient
  ) throws -> ImportMetrics {
    try fileClient.createDirectory(destinationRoot, true)
    let (planResult, planDuration) = measure {
      PersonaPackImportPlan.plan(from: selection, fileClient: fileClient)
    }
    let plan: PersonaPackImportPlan
    switch planResult {
    case .success(let result):
      plan = result
    case .failure(let error):
      throw AppOpsError(error.userFacingMessage)
    }

    let existing = existingPackDirectoryNames(in: destinationRoot, fileClient: fileClient)
    let preferred = PersonaKitStorage.preferredPackDirectoryName(for: plan.pack)
    let folderName = PersonaKitStorage.uniquePackDirectoryName(
      preferred: preferred, existing: existing)
    let destination = destinationRoot.appendingPathComponent(folderName, isDirectory: true)
    let tempFolderName = ".import_tmp_\(UUID().uuidString)"
    let tempDestination = destinationRoot.appendingPathComponent(tempFolderName, isDirectory: true)

    let (copyResult, copyDuration) = try measure {
      try copyImportFiles(
        plan: plan,
        tempDestination: tempDestination,
        finalDestination: destination,
        fileClient: fileClient
      )
    }

    return ImportMetrics(
      planDurationSeconds: planDuration,
      copyDurationSeconds: copyDuration,
      filesCopied: copyResult.filesCopied,
      bytesCopied: copyResult.bytesCopied,
      destinationRoot: destination.path
    )
  }

  private static func copyImportFiles(
    plan: PersonaPackImportPlan,
    tempDestination: URL,
    finalDestination: URL,
    fileClient: FileClient
  ) throws -> (filesCopied: Int, bytesCopied: Int64) {
    var bytesCopied: Int64 = 0
    do {
      try fileClient.createDirectory(tempDestination, true)
      for file in plan.filesToCopy {
        guard let relativePath = plan.relativePath(for: file) else {
          throw AppOpsError("Import file is outside the source root: \(file.path)")
        }
        let target = tempDestination.appendingPathComponent(relativePath)
        let targetFolder = target.deletingLastPathComponent()
        try fileClient.createDirectory(targetFolder, true)
        try fileClient.copyItem(file, target)
        bytesCopied += fileSize(file)
      }
      try fileClient.moveItem(tempDestination, finalDestination)
    } catch {
      try? fileClient.removeItem(tempDestination)
      throw error
    }
    return (plan.filesToCopy.count, bytesCopied)
  }

  private static func measureExport(
    sets: [PersonaSet],
    outputRoot: URL,
    fileClient: FileClient
  ) throws -> ExportMetrics {
    guard let set = sets.first else {
      throw AppOpsError("No persona sets available for export.")
    }
    try fileClient.createDirectory(outputRoot, true)
    let fileName = "\(PersonaKitStorage.preferredPackDirectoryName(for: set.pack)).pack.json"
    let outputPath = outputRoot.appendingPathComponent(fileName)
    let (bytesWritten, duration) = try measure {
      let document = PackExportDocument(
        schemaVersion: 1,
        documentType: "personaPack",
        pack: set.pack,
        defaults: set.defaults,
        personas: set.personas
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(document)
      try fileClient.writeData(data, outputPath, .atomic)
      return Int64(data.count)
    }
    return ExportMetrics(
      durationSeconds: duration,
      bytesWritten: bytesWritten,
      outputPath: outputPath.path
    )
  }

  private static func loadSet(url: URL, sourceKind: PersonaSource.Kind) throws -> PersonaSet {
    switch PersonaLoader.loadDocument(from: url, sourceKind: sourceKind) {
    case .success(let set):
      return set
    case .failure(let error):
      let message = error.diagnostics.first?.userFacingMessage ?? "Failed to load pack."
      throw AppOpsError(message)
    }
  }

  private static func diffRecords(for set: PersonaSet) -> [PersonaDiffRecord] {
    set.personas.map { persona in
      let key = PackDiffBuilder.personaKey(id: persona.id, fileURL: nil)
      return PersonaDiffRecord(
        key: key,
        id: persona.id,
        name: persona.name,
        contentHash: PackDiffBuilder.contentHash(for: persona)
      )
    }
  }

  private static func sampleSections(for persona: Persona) -> [String: String] {
    let keys =
      persona.template?.sections?.map { $0.key }
      ?? ["context", "goal", "constraints", "evidence", "task"]
    var sections: [String: String] = [:]
    for key in keys {
      sections[key] = "Sample \(key)"
    }
    return sections
  }

  private static func existingPackDirectoryNames(
    in packsRoot: URL,
    fileClient: FileClient
  ) -> Set<String> {
    guard let contents = try? fileClient.contentsOfDirectory(packsRoot, [.isDirectoryKey]) else {
      return []
    }
    return Set(
      contents.compactMap { url in
        fileClient.isDirectory(url) ? url.lastPathComponent : nil
      }
    )
  }

  private static func measure<T>(_ work: () throws -> T) rethrows -> (T, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try work()
    let end = DispatchTime.now().uptimeNanoseconds
    let duration = Double(end - start) / 1_000_000_000
    return (value, duration)
  }

  private static func writeReport(
    _ report: AppOpsReport,
    jsonURL: URL,
    markdownURL: URL,
    fileClient: FileClient
  ) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    try fileClient.writeData(data, jsonURL, .atomic)

    let markdown = AppOpsReportFormatter.markdown(report: report)
    guard let markdownData = markdown.data(using: .utf8) else {
      throw AppOpsError("Failed to encode markdown report.")
    }
    try fileClient.writeData(markdownData, markdownURL, .atomic)
  }

  static func defaultRepoRoot() throws -> URL {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "rev-parse", "--show-toplevel"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
      throw AppOpsError("Failed to locate repo root:\n\(output)")
    }
    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.isEmpty {
      throw AppOpsError("Empty repo root from git.")
    }
    return URL(fileURLWithPath: path)
  }

  static func defaultRunCommand(_ args: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let output = String(data: data, encoding: .utf8) ?? ""
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func resolvePath(_ path: String, relativeTo root: URL) -> URL {
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: path, relativeTo: root).standardizedFileURL
  }

  private static func isoTimestampUTC(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func fileSize(_ url: URL) -> Int64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
  }

  private static func printUsage() {
    print(
      """
      Usage:
        Scripts/appops [options]

      Options:
        --out-dir <path>        Output directory (default: Artifacts/)
        --import-source <path>  Pack file or folder to import (default: Examples/personakit.pack.json)
        --diff-left <path>      Left pack file for diff (default: built-in pack)
        --diff-right <path>     Right pack file for diff (default: Examples/personakit.pack.json)
        --no-user-packs         Skip loading ~/Library/Application Support/PersonaKit/Packs
        --help                  Show this message
      """
    )
  }

  private struct PackExportDocument: Codable {
    let schemaVersion: Int
    let documentType: String
    let pack: PackMeta
    let defaults: PackDefaults?
    let personas: [Persona]
  }

  private struct AppOpsError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
      self.message = message
    }

    var description: String {
      message
    }
  }

  private static func parseArgs(_ args: [String]) -> ParsedArgs {
    var parsed = ParsedArgs()
    var idx = 0
    while idx < args.count {
      let arg = args[idx]
      if arg.hasPrefix("--") {
        let key = String(arg.dropFirst(2))
        if idx + 1 < args.count, !args[idx + 1].hasPrefix("--") {
          parsed.values[key] = args[idx + 1]
          idx += 2
        } else {
          parsed.flags.insert(key)
          idx += 1
        }
      } else {
        idx += 1
      }
    }
    return parsed
  }

  static func defaultBuiltInPackURLs(repoRoot: URL) -> [URL] {
    var urls = PersonaPackLocator.builtInPackURLs(bundle: PersonaKitResources.bundle)
    if urls.isEmpty {
      urls = PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }
    return urls
  }

  private static func emptyReport() -> AppOpsReport {
    AppOpsReport(
      schemaVersion: 1,
      run: RunMetadata(timestampUTC: "", repoRoot: "", outputRoot: "", gitSha: ""),
      environment: EnvironmentInfo(macOSVersion: "", swiftVersion: "", xcodeVersion: ""),
      inputs: InputConfig(
        builtInSources: [],
        userPacksRoot: nil,
        includeUserPacks: false,
        importSource: "",
        diffLeft: "",
        diffRight: ""
      ),
      reload: ReloadMetrics(
        totalDurationSeconds: 0,
        builtIn: LoadMetrics(
          durationSeconds: 0, packCount: 0, personaCount: 0, diagnosticsCount: 0),
        userPacks: nil,
        merge: MergeMetrics(durationSeconds: 0, personaCount: 0, diagnosticsCount: 0),
        resolve: ResolveMetrics(durationSeconds: 0, personaCount: 0, diagnosticsCount: 0),
        totalPacks: 0,
        totalPersonas: 0,
        diagnosticsCount: 0
      ),
      compose: ComposeMetrics(
        durationSeconds: 0, personaCount: 0, promptBytesTotal: 0, jsonBytesTotal: 0),
      diff: DiffMetrics(
        durationSeconds: 0,
        leftPersonaCount: 0,
        rightPersonaCount: 0,
        addedCount: 0,
        removedCount: 0,
        modifiedCount: 0
      ),
      importMetrics: ImportMetrics(
        planDurationSeconds: 0,
        copyDurationSeconds: 0,
        filesCopied: 0,
        bytesCopied: 0,
        destinationRoot: ""
      ),
      exportMetrics: ExportMetrics(durationSeconds: 0, bytesWritten: 0, outputPath: "")
    )
  }
}
