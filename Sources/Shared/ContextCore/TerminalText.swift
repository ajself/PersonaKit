import Foundation

/// Text for a terminal or a reader: strips the characters that let `.personakit` content steer a terminal or
/// hide from a person.
///
/// A repo's entity text could otherwise retitle or clear the terminal, write the clipboard, or hide or
/// reorder text so a person reviewing output does not see what an agent reads. The CLI applies it to its
/// output, MCP to the export and graph it hands an agent, and Studio to the handoff preview it copies and exports.
public enum TerminalText {
  /// Removes C0 controls other than tab and newline, DEL, C1 controls, line and paragraph separators,
  /// bidirectional marks, overrides and isolates, invisible formatting and filler characters, Unicode tag
  /// characters, and the supplementary variation selectors. The last two render as nothing but a model still
  /// reads them. ZWJ, ZWNJ and the basic variation selectors stay, since emoji and many scripts need them.
  public static func sanitized(_ text: String) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.filter(isAllowed)))
  }

  /// Escapes the same characters as `\uXXXX` in a JSON document, so it stays exact but prints safely. A JSON
  /// encoder escapes only C0 controls, and outside strings a document holds only ASCII structure and
  /// whitespace, so every character escaped here sits inside a string.
  public static func escapingJSON(_ json: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in json.unicodeScalars {
      guard !isAllowed(scalar) else {
        result.append(scalar)
        continue
      }
      for unit in String(scalar).utf16 {
        result.append(contentsOf: String(format: "\\u%04x", unit).unicodeScalars)
      }
    }
    return String(result)
  }

  private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x09, 0x0A:
      return true
    case 0x00...0x1F, 0x7F...0x9F, 0x00AD, 0x034F, 0x061C, 0x115F, 0x1160, 0x180E, 0x200B, 0x200E, 0x200F,
      0x2028, 0x2029, 0x202A...0x202E, 0x2060...0x2069, 0x3164, 0xFEFF, 0xFFF9...0xFFFB, 0xE0000...0xE007F,
      0xE0100...0xE01EF:
      return false
    default:
      return true
    }
  }
}
