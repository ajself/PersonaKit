import Foundation

/// Loads built-in persona packs from bundles or a repo checkout.
public enum PersonaBuiltInPackLoader {
  /// Loads built-in persona sets from the provided bundle and optional repo root.
  public static func loadBuiltInSets(
    bundle: Bundle,
    repoRoot: URL? = nil,
    missingResourcesMessage: String
  ) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    var builtInURLs = PersonaPackLocator.builtInPackURLs(bundle: bundle)
    if builtInURLs.isEmpty, let repoRoot {
      builtInURLs = PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }

    guard !builtInURLs.isEmpty else {
      return (
        sets: [],
        diagnostics: [
          .warning(
            source: PersonaSource(kind: .builtIn, url: nil),
            message: missingResourcesMessage
          )
        ]
      )
    }

    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []
    for url in builtInURLs {
      switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
      case .success(let set):
        sets.append(set)
      case .failure(let error):
        diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return (sets: sets, diagnostics: diagnostics)
  }
}
