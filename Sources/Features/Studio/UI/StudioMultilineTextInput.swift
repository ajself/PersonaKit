import AppKit
import SwiftUI

/// Reusable multiline text input with controllable text-container insets.
struct StudioMultilineTextInput: View {
  @Binding var text: String
  var placeholder: String = ""
  var font: NSFont = .monospacedSystemFont(
    ofSize: NSFont.systemFontSize,
    weight: .regular
  )
  var textColor: NSColor = .labelColor
  var horizontalInset: CGFloat = 12
  var verticalInset: CGFloat = 10
  var lineFragmentPadding: CGFloat = 0

  var body: some View {
    ZStack(alignment: .topLeading) {
      AppKitMultilineTextInput(
        text: $text,
        font: font,
        textColor: textColor,
        horizontalInset: horizontalInset,
        verticalInset: verticalInset,
        lineFragmentPadding: lineFragmentPadding
      )

      if text.isEmpty, !placeholder.isEmpty {
        Text(placeholder)
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
          .padding(.top, verticalInset + 4)
          .padding(.leading, horizontalInset + 2)
      }
    }
  }
}

extension StudioMultilineTextInput {
  private struct AppKitMultilineTextInput: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let lineFragmentPadding: CGFloat

    func makeCoordinator() -> Coordinator {
      Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
      let scrollView = NSScrollView()
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true
      scrollView.drawsBackground = false
      scrollView.borderType = .noBorder

      let textView = NSTextView()
      textView.delegate = context.coordinator
      textView.isEditable = true
      textView.isSelectable = true
      textView.isRichText = false
      textView.importsGraphics = false
      textView.allowsUndo = true
      textView.drawsBackground = false
      textView.isVerticallyResizable = true
      textView.isHorizontallyResizable = false
      textView.maxSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
      )
      textView.minSize = NSSize(width: 0, height: 0)
      textView.textContainerInset = NSSize(
        width: horizontalInset,
        height: verticalInset
      )
      textView.textContainer?.lineFragmentPadding = lineFragmentPadding
      textView.textContainer?.widthTracksTextView = true
      textView.textContainer?.containerSize = NSSize(
        width: 0,
        height: CGFloat.greatestFiniteMagnitude
      )
      textView.font = font
      textView.textColor = textColor
      textView.string = text

      scrollView.documentView = textView
      return scrollView
    }

    func updateNSView(
      _ scrollView: NSScrollView,
      context: Context
    ) {
      guard let textView = scrollView.documentView as? NSTextView else {
        return
      }

      if textView.string != text {
        textView.string = text
      }

      textView.font = font
      textView.textColor = textColor
      textView.textContainerInset = NSSize(
        width: horizontalInset,
        height: verticalInset
      )
      textView.textContainer?.lineFragmentPadding = lineFragmentPadding
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String

    init(text: Binding<String>) {
      _text = text
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else {
        return
      }

      text = textView.string
    }
  }
}
