import PersonaKitCore
import SwiftUI

/// The PersonaKit macOS app entry point.
///
/// This root scene wires the shared ``AppModel`` into the view hierarchy and
/// installs the app-level commands used for pack management and navigation.
@main
struct PersonaKitAppMain: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  @State private var model = AppModel()
  @State private var showPersonaSwitcher = false
  @State private var showInspector = false

  /// Defines the main window scene and the command groups for PersonaKit.
  var body: some Scene {
    WindowGroup("PersonaKit") {
      ContentView(showPersonaSwitcher: $showPersonaSwitcher, showInspector: $showInspector)
        .environment(model)
        .frame(minWidth: 1100, minHeight: 700)
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .newItem) {
        Button("Import Pack…") {
          model.importPack()
        }

        Divider()

        Button("Reveal PersonaKit Storage") {
          model.revealStorageRoot()
        }

        Button("Reveal Selected Pack in Finder") {
          model.revealSelectedPack()
        }
        .disabled(!model.canRevealSelectedPack)

        Button("Remove Selected Pack…") {
          model.removeSelectedPack()
        }
        .disabled(!model.canRemoveSelectedPack)
      }
      PersonaKitCommands(
        model: model,
        showPersonaSwitcher: $showPersonaSwitcher,
        showInspector: $showInspector
      )
    }
  }
}

/// AppKit delegate that opts the app into a regular activation policy.
private final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Brings PersonaKit to the foreground on launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
