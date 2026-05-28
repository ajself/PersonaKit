import AppKit
import StudioFeatures
import SwiftUI

@main
struct PersonaKitApp: App {
  @NSApplicationDelegateAdaptor(PersonaKitAppDelegate.self) private var appDelegate
  @State private var workspaceStore = WorkspaceStore.launchConfigured()
  private let initialSection = StudioLaunchConfiguration.initialSection()

  var body: some Scene {
    WindowGroup {
      StudioRootView(
        workspaceStore: workspaceStore,
        initialSection: initialSection
      )
    }
    .defaultSize(
      width: StudioWindowSizingPolicy.defaultSize.width,
      height: StudioWindowSizingPolicy.defaultSize.height
    )
    .commands {
      StudioAppCommands(workspaceStore: workspaceStore)
    }
  }
}

@MainActor
private final class PersonaKitAppDelegate: NSObject, NSApplicationDelegate {
  private var initiallySizedWindowIDs: Set<ObjectIdentifier> = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureWindowSizing()

    guard StudioLaunchConfiguration.shouldAutoActivate() else {
      return
    }

    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  func applicationWillTerminate(_ notification: Notification) {
    NotificationCenter.default.removeObserver(self)
  }

  private func configureWindowSizing() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeMain(_:)),
      name: NSWindow.didBecomeMainNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidChangeScreen(_:)),
      name: NSWindow.didChangeScreenNotification,
      object: nil
    )

    DispatchQueue.main.async { [weak self] in
      self?.applyInitialSizingToOpenWindows()
    }
  }

  private func applyInitialSizingToOpenWindows() {
    for window in NSApplication.shared.windows {
      applyInitialSizing(to: window)
    }
  }

  private func applyInitialSizing(to window: NSWindow) {
    guard StudioWindowSizingPolicy.shouldSize(window) else {
      return
    }

    window.minSize = StudioWindowSizingPolicy.minimumSize
    window.contentMinSize = .zero
    let windowID = ObjectIdentifier(window)

    guard initiallySizedWindowIDs.insert(windowID).inserted else {
      return
    }

    StudioWindowSizingPolicy.clampToPreferredLaunchFrame(window)
  }

  @objc
  private func windowDidBecomeMain(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else {
      return
    }

    applyInitialSizing(to: window)
  }

  @objc
  private func windowDidChangeScreen(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else {
      return
    }

    guard StudioWindowSizingPolicy.shouldSize(window) else {
      return
    }

    StudioWindowSizingPolicy.clampToVisibleFrame(window)
  }
}

@MainActor
private enum StudioWindowSizingPolicy {
  static let defaultSize = CGSize(width: 1080, height: 720)
  static let minimumSize = CGSize(width: 520, height: 500)

  private static let screenMargin = CGFloat(24)

  static func shouldSize(_ window: NSWindow) -> Bool {
    window.sheetParent == nil
      && window.parent == nil
      && window.level == .normal
  }

  static func clampToPreferredLaunchFrame(_ window: NSWindow) {
    clamp(
      window,
      maximumSize: defaultSize
    )
  }

  static func clampToVisibleFrame(_ window: NSWindow) {
    clamp(
      window,
      maximumSize: nil
    )
  }

  private static func clamp(
    _ window: NSWindow,
    maximumSize: CGSize?
  ) {
    let clampedFrame = clampedFrame(
      for: window.frame,
      maximumSize: maximumSize,
      visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    )

    guard !window.frame.equalTo(clampedFrame) else {
      return
    }

    window.setFrame(clampedFrame, display: true)
  }

  private static func clampedFrame(
    for frame: CGRect,
    maximumSize: CGSize?,
    visibleFrame: CGRect?
  ) -> CGRect {
    guard let visibleFrame else {
      return frame
    }

    let availableFrame = visibleFrame.insetBy(
      dx: min(screenMargin, visibleFrame.width / 2),
      dy: min(screenMargin, visibleFrame.height / 2)
    )
    let maximumWidth = min(maximumSize?.width ?? frame.width, availableFrame.width)
    let maximumHeight = min(maximumSize?.height ?? frame.height, availableFrame.height)
    let clampedWidth = min(frame.width, maximumWidth)
    let clampedHeight = min(frame.height, maximumHeight)
    let maxX = availableFrame.maxX - clampedWidth
    let maxY = availableFrame.maxY - clampedHeight
    let clampedX = min(max(frame.minX, availableFrame.minX), maxX)
    let clampedY = min(max(frame.minY, availableFrame.minY), maxY)

    return CGRect(
      x: clampedX,
      y: clampedY,
      width: clampedWidth,
      height: clampedHeight
    )
  }
}
