import Foundation

public enum PersonaLoader {
  public static func loadDocument(from url: URL, sourceKind: PersonaSource.Kind) -> Result<PersonaSet, DiagnosticError> {
    let source = PersonaSource(kind: sourceKind, url: url)
    do {
      let data = try Data(contentsOf: url)
      let doc = try JSONDecoder().decode(PersonaDocumentEnvelope.self, from: data)
      return doc.asResolvedSet(source: source)
    } catch {
      return .failure(DiagnosticError([.error(
        source: source,
        message: "Failed to decode JSON: \(error.localizedDescription). Fix: ensure the file is valid JSON and matches schema v1."
      )]))
    }
  }

  public static func loadDocuments(in directory: URL, sourceKind: PersonaSource.Kind) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []

    let fm = FileManager.default
    let contents: [URL]
    do {
      contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    } catch {
      diagnostics.append(.warning(
        source: PersonaSource(kind: sourceKind, url: directory),
        message: "Could not read directory. Fix: ensure the directory exists and is readable. (\(error.localizedDescription))"
      ))
      return (sets, diagnostics)
    }

    let jsonFiles = contents
      .filter { $0.pathExtension.lowercased() == "json" }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    for f in jsonFiles {
      switch loadDocument(from: f, sourceKind: sourceKind) {
      case .success(let set): sets.append(set)
      case .failure(let error): diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return (sets, diagnostics)
  }
}
