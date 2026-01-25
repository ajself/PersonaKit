import Foundation

public enum PersonaResolver {

  public struct ResolutionResult: Sendable {
    public let personasByID: [String: ResolvedPersona]
    public let diagnostics: [Diagnostic]
  }

  /// Merge multiple sets into a single ID map. Later sets override earlier sets by persona id.
  public static func mergeSets(
    _ sets: [PersonaSet]
  ) -> (personas: [String: Persona], diagnostics: [Diagnostic]) {
    var merged: [String: Persona] = [:]
    var diags: [Diagnostic] = []
    var sourcesByID: [String: PersonaSource] = [:]

    // Load order matters: earlier then overridden by later.
    for set in sets {
      for p in set.personas {
        if sourcesByID[p.id] != nil {
          diags.append(
            .warning(
              source: set.source,
              message:
                "Persona '\(p.id)' overrides an earlier definition. Fix: remove duplicates or adjust pack load order."
            ))
        }
        merged[p.id] = p
        sourcesByID[p.id] = set.source
      }
    }

    return (merged, diags)
  }

  public static func resolveAll(from merged: [String: Persona]) -> ResolutionResult {
    let diags: [Diagnostic] = []
    var resolved: [String: ResolvedPersona] = [:]

    for id in merged.keys.sorted() {
      guard let persona = merged[id] else { continue }
      resolved[id] = ResolvedPersona(baseIDs: [persona.id], persona: persona)
    }

    return ResolutionResult(personasByID: resolved, diagnostics: diags)
  }
}
