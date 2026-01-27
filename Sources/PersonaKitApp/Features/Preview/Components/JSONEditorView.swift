import AppKit
import SwiftUI

/// A SwiftUI wrapper around an AppKit text view with JSON highlighting.
struct JSONEditorView: NSViewRepresentable {
  @Binding var text: String
  var isEditable: Bool = false

  /// Creates a coordinator to bridge AppKit delegate events.
  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  /// Builds the scroll view hosting the syntax-aware text view.
  func makeNSView(context: Context) -> NSScrollView {
    let textView = JSONSyntaxTextView()
    textView.isEditable = isEditable
    textView.isSelectable = true
    textView.isRichText = false
    textView.allowsUndo = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticTextCompletionEnabled = false
    textView.usesFindBar = true
    textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    textView.textColor = .textColor
    textView.insertionPointColor = .textColor
    textView.drawsBackground = true
    textView.backgroundColor = .textBackgroundColor
    textView.textContainer?.lineBreakMode = .byWordWrapping
    textView.textContainer?.widthTracksTextView = true
    textView.textContainerInset = NSSize(width: 6, height: 8)
    textView.delegate = context.coordinator

    textView.setTextPreservingSelection(text)

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false

    return scrollView
  }

  /// Keeps the AppKit view in sync with the bound text and editability.
  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? JSONSyntaxTextView else { return }
    textView.isEditable = isEditable
    if textView.string != text {
      textView.setTextPreservingSelection(text)
    } else {
      textView.updateAppearanceIfNeeded()
    }
  }
}

extension JSONEditorView {
  /// Coordinator that forwards AppKit text events to the SwiftUI binding.
  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding private var text: String

    init(text: Binding<String>) {
      _text = text
    }

    /// Updates the bound text and re-applies syntax highlighting.
    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text = textView.string
      if let jsonView = textView as? JSONSyntaxTextView {
        jsonView.applySyntaxHighlighting()
      }
    }

    /// Updates bracket highlighting when the caret moves.
    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? JSONSyntaxTextView else { return }
      textView.updateBracketHighlight()
    }
  }
}

/// NSTextView subclass that highlights JSON and matching brackets.
final class JSONSyntaxTextView: NSTextView {
  private let highlighter = JSONSyntaxHighlighter()
  private var braceHighlightRanges: [NSRange] = []
  private var cachedAppearanceName: NSAppearance.Name?

  /// Sets the text while keeping the caret position stable.
  func setTextPreservingSelection(_ text: String) {
    let priorSelection = selectedRange()
    var attrs: [NSAttributedString.Key: Any] = [:]
    attrs[.font] =
      font ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    attrs[.foregroundColor] = NSColor.textColor
    textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attrs))
    let clampedLocation = min(priorSelection.location, text.count)
    setSelectedRange(NSRange(location: clampedLocation, length: 0))
    applySyntaxHighlighting()
  }

  /// Re-applies highlighting when the system appearance changes.
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateAppearanceIfNeeded()
  }

  /// Updates cached appearance and re-highlights when needed.
  func updateAppearanceIfNeeded() {
    let name = effectiveAppearance.name
    if cachedAppearanceName != name {
      cachedAppearanceName = name
      applySyntaxHighlighting()
    }
  }

  /// Applies JSON syntax highlighting and bracket highlighting.
  func applySyntaxHighlighting() {
    guard let textStorage else { return }
    highlighter.apply(to: textStorage, font: font)
    updateBracketHighlight()
  }

  /// Highlights matching brackets when the caret is adjacent.
  func updateBracketHighlight() {
    guard let layoutManager else { return }
    clearBracketHighlights()

    let selection = selectedRange()
    guard selection.length == 0 else { return }

    let fullText = string
    guard !fullText.isEmpty else { return }

    let caret = selection.location
    let indexToCheck: Int?
    if caret > 0, isBracket(at: caret - 1, in: fullText) {
      indexToCheck = caret - 1
    } else if caret < fullText.count, isBracket(at: caret, in: fullText) {
      indexToCheck = caret
    } else {
      indexToCheck = nil
    }

    guard let index = indexToCheck,
      let match = findMatchingBracket(from: index, in: fullText)
    else { return }

    var ranges = [NSRange(location: index, length: 1)]
    ranges.append(NSRange(location: match, length: 1))
    let highlightColor = NSColor.controlAccentColor.withAlphaComponent(0.25)
    for range in ranges {
      layoutManager.addTemporaryAttribute(
        .backgroundColor, value: highlightColor, forCharacterRange: range)
    }
    braceHighlightRanges = ranges
  }

  /// Clears temporary background attributes used for bracket matching.
  private func clearBracketHighlights() {
    guard let layoutManager else { return }
    for range in braceHighlightRanges {
      layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
    }
    braceHighlightRanges.removeAll()
  }

  /// Returns true when the character at the index is a JSON bracket.
  private func isBracket(at index: Int, in text: String) -> Bool {
    guard index >= 0, index < text.count else { return false }
    let ch = text[text.index(text.startIndex, offsetBy: index)]
    return ch == "{" || ch == "}" || ch == "[" || ch == "]"
  }

  /// Finds the matching bracket index, ignoring text inside strings.
  private func findMatchingBracket(from index: Int, in text: String) -> Int? {
    guard index >= 0, index < text.count else { return nil }
    let ch = text[text.index(text.startIndex, offsetBy: index)]

    let pairs: [Character: Character] = ["{": "}", "[": "]"]
    let reversePairs: [Character: Character] = ["}": "{", "]": "["]

    if let closing = pairs[ch] {
      return scanForward(from: index + 1, open: ch, close: closing, in: text)
    }
    if let opening = reversePairs[ch] {
      return scanBackward(from: index - 1, open: opening, close: ch, in: text)
    }
    return nil
  }

  /// Scans forward to find the closing bracket that matches the opening.
  private func scanForward(
    from start: Int, open: Character, close: Character, in text: String
  ) -> Int? {
    var depth = 1
    var inString = false
    var escaped = false
    let chars = Array(text)
    guard start <= chars.count else { return nil }
    for index in start..<chars.count {
      let ch = chars[index]
      if inString {
        if escaped {
          escaped = false
        } else if ch == "\\" {
          escaped = true
        } else if ch == "\"" {
          inString = false
        }
        continue
      } else {
        if ch == "\"" {
          inString = true
          continue
        }
        if ch == open { depth += 1 }
        if ch == close { depth -= 1 }
        if depth == 0 { return index }
      }
    }
    return nil
  }

  /// Scans backward to find the opening bracket that matches the closing.
  private func scanBackward(
    from start: Int, open: Character, close: Character, in text: String
  ) -> Int? {
    var depth = 1
    var inString = false
    var escaped = false
    let chars = Array(text)
    guard start >= 0 else { return nil }
    var index = start
    while index >= 0 {
      let ch = chars[index]
      if inString {
        if escaped {
          escaped = false
        } else if ch == "\\" {
          escaped = true
        } else if ch == "\"" {
          inString = false
        }
        index -= 1
        continue
      } else {
        if ch == "\"" {
          inString = true
          index -= 1
          continue
        }
        if ch == close { depth += 1 }
        if ch == open { depth -= 1 }
        if depth == 0 { return index }
      }
      index -= 1
    }
    return nil
  }
}

/// Applies basic JSON syntax highlighting to a text storage.
final class JSONSyntaxHighlighter {
  private struct Theme {
    let base: NSColor
    let key: NSColor
    let string: NSColor
    let number: NSColor
    let boolean: NSColor
    let null: NSColor
  }

  /// Applies the full highlighting theme to the text storage.
  func apply(to textStorage: NSTextStorage, font: NSFont?) {
    let theme = Theme(
      base: .textColor,
      key: .systemBlue,
      string: .systemBrown,
      number: .systemOrange,
      boolean: .systemGreen,
      null: .secondaryLabelColor
    )

    let fullRange = NSRange(location: 0, length: textStorage.length)
    let baseFont =
      font ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    textStorage.setAttributes([.foregroundColor: theme.base, .font: baseFont], range: fullRange)

    apply(pattern: "\"(?:\\\\.|[^\"\\\\])*\"(?=\\s*:)", color: theme.key, to: textStorage)
    apply(pattern: "\"(?:\\\\.|[^\"\\\\])*\"", color: theme.string, to: textStorage)
    apply(
      pattern: "-?\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", color: theme.number, to: textStorage)
    apply(pattern: "\\btrue\\b|\\bfalse\\b", color: theme.boolean, to: textStorage)
    apply(pattern: "\\bnull\\b", color: theme.null, to: textStorage)
  }

  /// Applies a regex color rule to the text storage.
  private func apply(pattern: String, color: NSColor, to textStorage: NSTextStorage) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
    let fullRange = NSRange(location: 0, length: textStorage.length)
    regex.enumerateMatches(in: textStorage.string, options: [], range: fullRange) { match, _, _ in
      guard let match else { return }
      textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
    }
  }
}
