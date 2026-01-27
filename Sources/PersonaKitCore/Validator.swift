import Foundation

/// Performs schema v1 validation for persona packs and personas.
public enum PersonaValidator {
  /// Validates a full persona set and returns diagnostics.
  public static func validate(set: PersonaSet) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    diagnostics.append(contentsOf: validatePack(set))
    diagnostics.append(contentsOf: validatePersonas(set))
    return diagnostics
  }

  private static func validatePack(_ set: PersonaSet) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    // Required fields (light validation; JSON Schema should do most)
    if set.pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diagnostics.append(
        .error(
          source: set.source,
          message: "Pack 'id' must be non-empty. Fix: set a stable pack id."
        ))
    }
    if set.pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diagnostics.append(
        .error(
          source: set.source,
          message: "Pack 'name' must be non-empty. Fix: set a human-readable pack name."
        ))
    }

    return diagnostics
  }

  private static func validatePersonas(_ set: PersonaSet) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    var seen = Set<String>()
    for persona in set.personas {
      diagnostics.append(contentsOf: validatePersona(persona, source: set.source, seen: &seen))
    }
    return diagnostics
  }

  private static func validatePersona(
    _ persona: Persona,
    source: PersonaSource,
    seen: inout Set<String>
  ) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    let id = persona.id.trimmingCharacters(in: .whitespacesAndNewlines)
    if id.isEmpty {
      diagnostics.append(
        .error(
          source: source,
          message: "Persona 'id' must be non-empty. Fix: set a unique persona id."
        ))
    }
    if seen.contains(id) {
      diagnostics.append(
        .error(
          source: source,
          message: "Duplicate persona id in pack: '\(id)'. Fix: ensure ids are unique."
        ))
    }
    seen.insert(id)

    if persona.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diagnostics.append(
        .error(
          source: source,
          message: "Persona '\(persona.id)' has empty 'name'. Fix: provide a display name."
        ))
    }
    if persona.system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diagnostics.append(
        .error(
          source: source,
          message: "Persona '\(persona.id)' has empty 'system'. Fix: provide a system prompt."
        ))
    }

    if let ext = persona.extends, !ext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diagnostics.append(
        .error(
          source: source,
          message:
            "Persona '\(persona.id)' uses 'extends', which is not supported in v1. Fix: "
            + "inline the parent content and remove 'extends'."
        ))
    }
    let hasSystemAppend =
      persona.systemAppend?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    if hasSystemAppend {
      diagnostics.append(
        .error(
          source: source,
          message:
            "Persona '\(persona.id)' uses 'systemAppend', which is not supported in v1. Fix: "
            + "merge the appended text into 'system'."
        ))
    }

    return diagnostics
  }
}
