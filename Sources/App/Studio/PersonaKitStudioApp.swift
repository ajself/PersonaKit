import AppKit
import StudioFeatures
import SwiftUI

/// Entry point for the PersonaKit Studio macOS app.
@main
struct PersonaKitStudioApp: App {
  @NSApplicationDelegateAdaptor(StudioAppDelegate.self) private var appDelegate
  @State private var workspaceStore = WorkspaceStore.launchConfigured()
  private let initialSection = StudioLaunchConfiguration.initialSection()

  var body: some Scene {
    WindowGroup {
      StudioRootView(
        workspaceStore: workspaceStore,
        initialSection: initialSection
      )
    }
    .commands {
      StudioAppCommands(workspaceStore: workspaceStore)
    }
  }
}

@MainActor
private final class StudioAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard StudioLaunchConfiguration.shouldAutoActivate() else {
      return
    }

    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
