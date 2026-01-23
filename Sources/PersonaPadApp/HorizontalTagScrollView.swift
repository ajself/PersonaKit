import SwiftUI
import AppKit

struct HorizontalTagScrollView<Content: View>: NSViewRepresentable {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = HorizontalWheelScrollView()
    scrollView.hasHorizontalScroller = false
    scrollView.hasVerticalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    let hostingView = NSHostingView(rootView: content)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = hostingView

    NSLayoutConstraint.activate([
      hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
      hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor)
    ])

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let hostingView = nsView.documentView as? NSHostingView<Content> else { return }
    hostingView.rootView = content
    hostingView.needsLayout = true
    hostingView.layoutSubtreeIfNeeded()
  }
}

private final class HorizontalWheelScrollView: NSScrollView {
  override func scrollWheel(with event: NSEvent) {
    let deltaX = event.scrollingDeltaX
    let deltaY = event.scrollingDeltaY
    if deltaX != 0 || abs(deltaX) > abs(deltaY) {
      super.scrollWheel(with: event)
      return
    }

    guard let documentView else {
      super.scrollWheel(with: event)
      return
    }

    let maxX = max(0, documentView.bounds.width - contentView.bounds.width)
    guard maxX > 0 else {
      super.scrollWheel(with: event)
      return
    }

    let currentX = contentView.bounds.origin.x
    let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
    var newX = currentX + (deltaY * scale)
    newX = min(max(newX, 0), maxX)

    if newX != currentX {
      contentView.setBoundsOrigin(NSPoint(x: newX, y: contentView.bounds.origin.y))
      reflectScrolledClipView(contentView)
    } else {
      super.scrollWheel(with: event)
    }
  }
}
