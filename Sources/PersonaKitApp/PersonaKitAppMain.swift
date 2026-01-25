import PersonaKitCore
import SwiftUI

@main
struct PersonaKitAppMain: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  @State private var store = AppStore()
  @State private var showPersonaSwitcher = false
  @State private var showInspector = false

  var body: some Scene {
    WindowGroup("PersonaKit") {
      ContentView(showPersonaSwitcher: $showPersonaSwitcher, showInspector: $showInspector)
        .environment(store)
        .frame(minWidth: 1100, minHeight: 700)
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .newItem) {
        Button("Import Pack…") {
          store.send(.importPack)
        }

        Divider()

        Button("Reveal PersonaKit Storage") {
          store.send(.revealStorageRoot)
        }

        Button("Reveal Selected Pack in Finder") {
          store.send(.revealSelectedPack)
        }
        .disabled(!store.canRevealSelectedPack)

        Button("Remove Selected Pack…") {
          store.send(.removeSelectedPack)
        }
        .disabled(!store.canRemoveSelectedPack)
      }
      PersonaKitCommands(
        store: store,
        showPersonaSwitcher: $showPersonaSwitcher,
        showInspector: $showInspector
      )
    }
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
