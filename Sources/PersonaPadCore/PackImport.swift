import Foundation

public enum PersonaPackImportError: Error, Sendable, Equatable {
  case unsupportedSelection(URL)
  case missingPackFile(URL)
  case multiplePackFiles(URL, [URL])
  case invalidPackFile(URL, String)
  case fileOutsideSourceRoot(URL)

  public var userFacingMessage: String {
    switch self {
    case .unsupportedSelection(let url):
      return "Unsupported selection: \(url.lastPathComponent). Fix: choose a .pack.json file or a folder containing one."
    case .missingPackFile(let url):
      return "No .pack.json found in \(url.lastPathComponent). Fix: include a pack file in the selected folder."
    case .multiplePackFiles(_, let files):
      let names = files.map { $0.lastPathComponent }.sorted().joined(separator: ", ")
      return "Multiple .pack.json files found. Fix: keep one pack file per folder. Found: \(names)."
    case .invalidPackFile(let url, let message):
      return "Invalid pack file: \(url.lastPathComponent). Fix: \(message)"
    case .fileOutsideSourceRoot(let url):
      return "File is outside the pack folder: \(url.lastPathComponent). Fix: keep all pack files under the selected folder."
    }
  }
}

public struct PersonaPackImportPlan: Sendable, Hashable {
  public let sourceRoot: URL
  public let packFile: URL
  public let filesToCopy: [URL]
  public let pack: PackMeta

  public func relativePath(for file: URL) -> String? {
    PersonaPackImportPlan.relativePath(for: file, sourceRoot: sourceRoot)
  }

  public static func plan(
    from selection: URL,
    fileClient: FileClient? = nil
  ) -> Result<PersonaPackImportPlan, PersonaPackImportError> {
    let fileClient = fileClient ?? FileClientProvider().fileClient
    let isDirectory = fileClient.isDirectory(selection)

    if isDirectory {
      return planFromDirectory(selection, fileClient: fileClient)
    }

    guard selection.pathExtension.lowercased() == "json",
          selection.lastPathComponent.lowercased().hasSuffix(".pack.json") else {
      return .failure(.unsupportedSelection(selection))
    }
    let sourceRoot = selection.deletingLastPathComponent()
    let packFile = selection
    return planForPackFile(packFile, sourceRoot: sourceRoot, fileClient: fileClient)
  }

  private static func planFromDirectory(
    _ directory: URL,
    fileClient: FileClient
  ) -> Result<PersonaPackImportPlan, PersonaPackImportError> {
    guard let contents = try? fileClient.contentsOfDirectory(directory, nil) else {
      return .failure(.missingPackFile(directory))
    }
    let packFiles = contents
      .filter { $0.lastPathComponent.lowercased().hasSuffix(".pack.json") }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    guard let packFile = packFiles.first else {
      return .failure(.missingPackFile(directory))
    }
    if packFiles.count > 1 {
      return .failure(.multiplePackFiles(directory, packFiles))
    }
    return planForPackFile(packFile, sourceRoot: directory, fileClient: fileClient)
  }

  private static func planForPackFile(
    _ packFile: URL,
    sourceRoot: URL,
    fileClient: FileClient
  ) -> Result<PersonaPackImportPlan, PersonaPackImportError> {
    guard let data = try? fileClient.readData(packFile) else {
      return .failure(.invalidPackFile(packFile, "ensure the file is readable"))
    }
    guard let rawObject = try? JSONSerialization.jsonObject(with: data) else {
      return .failure(.invalidPackFile(packFile, "ensure the file is valid JSON."))
    }
    let rawType = (rawObject as? [String: Any])?["documentType"] as? String
    if rawType != "personaPack" {
      return .failure(.invalidPackFile(packFile, "documentType must be 'personaPack'."))
    }

    switch PersonaLoader.loadDocument(from: packFile, sourceKind: .user) {
    case .failure(let error):
      let message = error.diagnostics.first?.message ?? "ensure the file matches schema v1."
      return .failure(.invalidPackFile(packFile, message))
    case .success(let set):
      let companions = companionFiles(in: sourceRoot, excluding: packFile, fileClient: fileClient)
      let allFiles = [packFile] + companions
      var filesWithRelative: [(url: URL, relative: String)] = []
      for file in allFiles {
        guard let relative = relativePath(for: file, sourceRoot: sourceRoot) else {
          return .failure(.fileOutsideSourceRoot(file))
        }
        filesWithRelative.append((file, relative))
      }
      let sorted = filesWithRelative.sorted {
        $0.relative.localizedStandardCompare($1.relative) == .orderedAscending
      }
      return .success(PersonaPackImportPlan(
        sourceRoot: sourceRoot,
        packFile: packFile,
        filesToCopy: sorted.map(\.url),
        pack: set.pack
      ))
    }
  }

  private static func companionFiles(
    in directory: URL,
    excluding packFile: URL,
    fileClient: FileClient
  ) -> [URL] {
    guard let enumerator = fileClient.enumerator(
      directory,
      [.isDirectoryKey],
      [.skipsHiddenFiles]
    ) else {
      return []
    }

    var results: [URL] = []
    let packCanonical = packFile.resolvingSymlinksInPath().standardizedFileURL
    for case let url as URL in enumerator {
      let isDirectory = fileClient.isDirectory(url)
      if isDirectory { continue }
      let canonical = url.resolvingSymlinksInPath().standardizedFileURL
      if canonical == packCanonical { continue }
      let name = url.lastPathComponent.lowercased()
      if name.hasSuffix(".persona.json") || name.hasSuffix(".meta.json") || name.hasSuffix(".metadata.json") {
        results.append(url)
      }
    }
    return results
  }

  private static func relativePath(for file: URL, sourceRoot: URL) -> String? {
    let base = sourceRoot.resolvingSymlinksInPath().standardizedFileURL
    let target = file.resolvingSymlinksInPath().standardizedFileURL
    let baseComponents = base.pathComponents
    let targetComponents = target.pathComponents
    guard targetComponents.count >= baseComponents.count else { return nil }
    for (lhs, rhs) in zip(baseComponents, targetComponents) {
      if lhs != rhs { return nil }
    }
    let relativeComponents = targetComponents.dropFirst(baseComponents.count)
    guard !relativeComponents.isEmpty else { return nil }
    return relativeComponents.joined(separator: "/")
  }
}
