import AppKit
import StudioFeatures
import SwiftUI

@main
struct PersonaKitApp: App {
  @NSApplicationDelegateAdaptor(PersonaKitAppDelegate.self) private var appDelegate
  @State private var workspaceStore = WorkspaceStore()

  var body: some Scene {
    WindowGroup {
      StudioRootView(workspaceStore: workspaceStore)
    }
    .commands {
      StudioAppCommands(workspaceStore: workspaceStore)
    }
  }
}

@MainActor
private final class PersonaKitAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard PersonaKitLaunchConfiguration.shouldAutoActivate() else {
      return
    }

    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

enum PersonaKitLaunchConfiguration {
  static let disableAutoActivateEnvironmentKey = "PERSONAKIT_STUDIO_DISABLE_AUTO_ACTIVATE"

  static func shouldAutoActivate(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> Bool {
    if arguments.contains("--no-auto-activate") {
      return false
    }

    guard
      let rawValue = environment[disableAutoActivateEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      return true
    }

    switch rawValue.lowercased() {
    case "1", "true", "yes":
      return false
    default:
      return true
    }
  }
}
