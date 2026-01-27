import Foundation

/// Renders user-facing outputs from personas.
public enum PersonaOutputRenderer {
  /// Renders a composed prompt using the persona template.
  public static func prompt(persona: Persona, sections: [String: String]) -> String {
    PromptComposer.compose(persona: persona, sections: sections)
  }

  /// Encodes a persona as JSON with deterministic key ordering.
  public static func resolvedJSON(persona: Persona, prettyPrinted: Bool = true) -> String? {
    let encoder = JSONEncoder()
    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
      encoder.outputFormatting = [.sortedKeys]
    }
    guard let data = try? encoder.encode(persona),
      let text = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return text
  }
}
