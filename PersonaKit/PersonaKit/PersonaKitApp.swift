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
    .commands {
      StudioAppCommands(workspaceStore: workspaceStore)
    }
  }
}

@MainActor
private final class PersonaKitAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard StudioLaunchConfiguration.shouldAutoActivate() else {
      return
    }

    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
