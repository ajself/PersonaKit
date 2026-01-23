import Foundation

public enum PromptComposer {

  /// Compose a prompt using a resolved persona and user-provided section values.
  public static func compose(persona: Persona, sections: [String: String]) -> String {
    var parts: [String] = []
    parts.append(persona.system.trimmingCharacters(in: .whitespacesAndNewlines))

    if let template = persona.template, let tmplSections = template.sections, !tmplSections.isEmpty {
      parts.append("") // blank line
      for s in tmplSections {
        let value = (sections[s.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { continue }
        parts.append("\(s.label.uppercased())\n\(value)")
        parts.append("") // spacing
      }
    } else {
      // Fallback: dump any provided sections in key order.
      let keys = sections.keys.sorted()
      if !keys.isEmpty {
        parts.append("")
        for k in keys {
          let v = (sections[k] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          if v.isEmpty { continue }
          parts.append("\(k.uppercased())\n\(v)")
          parts.append("")
        }
      }
    }

    return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
  }
}
