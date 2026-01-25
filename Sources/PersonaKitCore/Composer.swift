import Foundation

public enum PromptComposer {

  /// Compose a prompt using a resolved persona and user-provided section values.
  public static func compose(persona: Persona, sections: [String: String]) -> String {
    var parts: [String] = []
    parts.append(persona.system.trimmingCharacters(in: .whitespacesAndNewlines))

    let templateSections = persona.template?.sections ?? []
    if !templateSections.isEmpty {
      parts.append("")  // blank line
      for section in templateSections {
        let value = (sections[section.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { continue }
        parts.append("\(section.label.uppercased())\n\(value)")
        parts.append("")  // spacing
      }
    } else {
      // Fallback: dump any provided sections in key order.
      let keys = sections.keys.sorted()
      if !keys.isEmpty {
        parts.append("")
        for key in keys {
          let value = (sections[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          if value.isEmpty { continue }
          parts.append("\(key.uppercased())\n\(value)")
          parts.append("")
        }
      }
    }

    return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
  }
}
