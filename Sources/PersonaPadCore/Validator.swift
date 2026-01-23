import Foundation

public enum PersonaValidator {
  public static func validate(set: PersonaSet) -> [Diagnostic] {
    var diags: [Diagnostic] = []

    // Required fields (light validation; JSON Schema should do most)
    if set.pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diags.append(.error(
        source: set.source,
        message: "Pack 'id' must be non-empty. Fix: set a stable pack id."
      ))
    }
    if set.pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      diags.append(.error(
        source: set.source,
        message: "Pack 'name' must be non-empty. Fix: set a human-readable pack name."
      ))
    }

    var seen = Set<String>()
    for p in set.personas {
      let id = p.id.trimmingCharacters(in: .whitespacesAndNewlines)
      if id.isEmpty {
        diags.append(.error(
          source: set.source,
          message: "Persona 'id' must be non-empty. Fix: set a unique persona id."
        ))
      }
      if seen.contains(id) {
        diags.append(.error(
          source: set.source,
          message: "Duplicate persona id in pack: '\(id)'. Fix: ensure ids are unique."
        ))
      }
      seen.insert(id)

      if p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diags.append(.error(
          source: set.source,
          message: "Persona '\(p.id)' has empty 'name'. Fix: provide a display name."
        ))
      }
      if p.system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diags.append(.error(
          source: set.source,
          message: "Persona '\(p.id)' has empty 'system'. Fix: provide a system prompt."
        ))
      }

      if let ext = p.extends, !ext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diags.append(.error(
          source: set.source,
          message: "Persona '\(p.id)' uses 'extends', which is not supported in v1. Fix: inline the parent content and remove 'extends'."
        ))
      }
      if let append = p.systemAppend, !append.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diags.append(.error(
          source: set.source,
          message: "Persona '\(p.id)' uses 'systemAppend', which is not supported in v1. Fix: merge the appended text into 'system'."
        ))
      }
    }

    return diags
  }
}
